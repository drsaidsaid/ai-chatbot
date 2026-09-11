# frozen_string_literal: true

class Conversations::ControlService
  class InvalidTransition < StandardError; end

  BLOCK_REASONS = AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS
  TAKEOVER_BLOCK_REASON = BLOCK_REASONS[:assigned_to_human_operator]
  HUMAN_ACTIVITY_BLOCK_REASON = BLOCK_REASONS[:human_reply_after_trigger]
  AUTOMATION_BLOCK_REASON = BLOCK_REASONS[:incompatible_control_state]
  BOT_HANDOFF_EVENT_TYPE = 'conversation.bot_handoff_requested'

  def self.invalidate_pending_ai!(conversation:, reason:)
    Whatsapp::OutboundDelivery.cancel_automation!(conversation: conversation, reason: reason)
    conversation.ai_orchestration_intents
                .where(state: %i[pending processing])
                .find_each do |intent|
      intent.update!(state: :blocked, blocked_reason: reason, blocked_at: Time.current)
    end
  end

  def initialize(conversation:, actor: nil)
    @conversation = conversation
    @actor = actor
  end

  def human_takeover!(operator: nil, action: 'human_takeover', block_reason: TAKEOVER_BLOCK_REASON)
    attributes = human_takeover_attributes(operator)
    if conversation.pending? && conversation.assignee_agent_bot_id.present?
      attributes[:status] = :open
      attributes[:waiting_since] = Time.current if conversation.waiting_since.blank?
    end
    transition!(attributes, action: action, block_reason: block_reason)
  end

  def open_for_human!(operator: nil)
    attributes = human_takeover_attributes(operator).merge(status: :open)
    attributes[:waiting_since] = Time.current if conversation.waiting_since.blank?
    transition!(attributes, action: 'human_takeover', block_reason: TAKEOVER_BLOCK_REASON)
  end

  def human_reply!(operator:)
    human_takeover!(operator: operator, action: 'human_reply', block_reason: HUMAN_ACTIVITY_BLOCK_REASON)
  end

  def team_assignment!
    human_takeover!(operator: conversation.assignee, action: 'team_assignment')
  end

  def coexistence_echo!
    human_takeover!(action: 'coexistence_echo', block_reason: HUMAN_ACTIVITY_BLOCK_REASON)
  end

  def pause_ai!
    transition!({ control_state: :ai_paused, assignee_agent_bot: nil },
                action: 'pause_ai', block_reason: AUTOMATION_BLOCK_REASON,
                validation: {
                  allowed_states: %w[ai_active handoff_requested human_active ai_paused],
                  invalid_state_message: 'AI can pause only for a non-closed conversation',
                  reject_resolved: true
                })
  end

  def resume_ai!
    transition!({ control_state: :ai_active, assignee: nil, assignee_agent_bot: nil },
                action: 'resume_ai', block_reason: AUTOMATION_BLOCK_REASON,
                validation: { allowed_states: %w[human_active ai_paused], reject_resolved: true })
  end

  def close!
    transition!({ control_state: :closed, assignee_agent_bot: nil }, action: 'close', block_reason: AUTOMATION_BLOCK_REASON)
  end

  def resolve!
    transition!({ status: :resolved, control_state: :closed, assignee_agent_bot: nil },
                action: 'close', block_reason: AUTOMATION_BLOCK_REASON)
  end

  def update_inbox_status!(status:, snoozed_until: nil)
    conversation.reload.with_lock do
      validate_actor_access!
      conversation.status = status
      conversation.snoozed_until = snoozed_until
      conversation.save!
    end
    true
  end

  def handoff_requested!
    attributes = { control_state: :handoff_requested, assignee_agent_bot: nil, status: :open }
    attributes[:waiting_since] = Time.current if conversation.waiting_since.blank?
    transition!(
      attributes,
      action: 'handoff_requested',
      block_reason: AUTOMATION_BLOCK_REASON,
      validation: {
        allowed_states: %w[ai_active],
        invalid_state_message: 'AI can request handoff only while active',
        reject_resolved: true
      },
      idempotent: method(:existing_bot_handoff_outbox)
    ) { record_bot_handoff_outbox! }
  end

  private

  attr_reader :actor, :conversation

  def human_takeover_attributes(operator)
    attributes = { control_state: :human_active, assignee_agent_bot: nil }
    attributes[:assignee] = operator if operator.present?
    attributes
  end

  def transition!(attributes, action:, block_reason:, validation: {}, idempotent: nil)
    result = true
    conversation.reload.with_lock do
      validate_actor_access!
      existing_result = idempotent&.call
      if existing_result
        result = existing_result
        next
      end

      validate_transition!(**validation)
      persist_transition!(attributes, action, block_reason)
      result = yield if block_given?
    end
    cancel_follow_ups!(attributes[:control_state])
    result
  end

  def persist_transition!(attributes, action, block_reason)
    previous_control_state = conversation.control_state
    previous_assignee_id = conversation.assignee_id
    conversation.assign_attributes(attributes)
    conversation.control_version += 1
    invalidate_pending_ai!(block_reason)
    conversation.save!
    audit_transition!(action, previous_control_state, previous_assignee_id)
  end

  def record_bot_handoff_outbox!
    OutboxEvent.create!(
      account: conversation.account,
      aggregate: conversation,
      event_type: BOT_HANDOFF_EVENT_TYPE,
      idempotency_key: bot_handoff_idempotency_key,
      payload: { conversation_id: conversation.id, control_version: conversation.control_version }
    )
  end

  def existing_bot_handoff_outbox
    return unless conversation.open? && conversation.handoff_requested?

    OutboxEvent.find_by!(account: conversation.account, idempotency_key: bot_handoff_idempotency_key)
  end

  def bot_handoff_idempotency_key
    "conversation-bot-handoff/#{conversation.id}/#{conversation.control_version}"
  end

  def validate_transition!(allowed_states: nil, invalid_state_message: nil, reject_resolved: false)
    raise InvalidTransition, 'A resolved conversation cannot change AI control' if reject_resolved && conversation.resolved?
    return if allowed_states.blank? || conversation.control_state.in?(allowed_states)

    raise InvalidTransition, invalid_state_message || 'AI can resume only from human active or AI paused'
  end

  def validate_actor_access!
    return if actor.blank?

    allowed = if actor.is_a?(AgentBot)
                Conversations::AgentBotControlAccess.allowed?(conversation: conversation, agent_bot: actor)
              else
                AiLeadEmployee::AccessScope.new(account: conversation.account, user: actor).conversations.exists?(id: conversation.id)
              end
    raise InvalidTransition, 'Conversation control access changed; refresh and try again' unless allowed
  end

  def invalidate_pending_ai!(block_reason)
    self.class.invalidate_pending_ai!(conversation: conversation, reason: block_reason)
  end

  def cancel_follow_ups!(control_state)
    return if control_state.to_s == 'ai_active'

    AiLeadEmployee::FollowUpScheduler.cancel_pending_for!(
      conversation: conversation,
      reason: "control_state_#{conversation.control_state}"
    )
  end

  def audit_transition!(action, previous_control_state, previous_assignee_id)
    Audited::Audit.create!(
      auditable: conversation,
      associated: conversation.account,
      user: Current.user,
      action: 'update',
      audited_changes: {
        'ai_lead_employee_action' => action,
        'control_state' => [previous_control_state, conversation.control_state],
        'assignee_id' => [previous_assignee_id, conversation.assignee_id]
      },
      version: next_audit_version,
      created_at: Time.current
    )
  end

  def next_audit_version
    Audited::Audit.where(auditable: conversation).maximum(:version).to_i + 1
  end
end
