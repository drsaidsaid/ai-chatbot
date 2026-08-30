# frozen_string_literal: true

class Conversations::ControlService
  class InvalidTransition < StandardError; end

  BLOCK_REASONS = AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS
  TAKEOVER_BLOCK_REASON = BLOCK_REASONS[:assigned_to_human_operator]
  HUMAN_ACTIVITY_BLOCK_REASON = BLOCK_REASONS[:human_reply_after_trigger]
  AUTOMATION_BLOCK_REASON = BLOCK_REASONS[:incompatible_control_state]

  def self.invalidate_pending_ai!(conversation:, reason:)
    conversation.ai_orchestration_intents
                .where(state: %i[pending processing])
                .find_each do |intent|
      intent.update!(state: :blocked, blocked_reason: reason, blocked_at: Time.current)
    end
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def human_takeover!(operator: nil, action: 'human_takeover', block_reason: TAKEOVER_BLOCK_REASON)
    attributes = { control_state: :human_active, assignee_agent_bot: nil }
    attributes[:assignee] = operator if operator.present?
    if conversation.pending? && conversation.assignee_agent_bot_id.present?
      attributes[:status] = :open
      attributes[:waiting_since] = Time.current if conversation.waiting_since.blank?
    end
    transition!(attributes, action: action, block_reason: block_reason)
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
    transition!({ control_state: :ai_paused, assignee_agent_bot: nil }, action: 'pause_ai', block_reason: AUTOMATION_BLOCK_REASON)
  end

  def resume_ai!
    raise InvalidTransition, 'Cannot resume AI for a closed conversation' if conversation.closed?

    transition!({ control_state: :ai_active, assignee_agent_bot: nil }, action: 'resume_ai', block_reason: AUTOMATION_BLOCK_REASON)
  end

  def close!
    transition!({ control_state: :closed, assignee_agent_bot: nil }, action: 'close', block_reason: AUTOMATION_BLOCK_REASON)
  end

  def handoff_requested!
    attributes = { control_state: :handoff_requested, assignee_agent_bot: nil, status: :open }
    attributes[:waiting_since] = Time.current if conversation.waiting_since.blank?
    transition!(attributes, action: 'handoff_requested', block_reason: AUTOMATION_BLOCK_REASON)
  end

  private

  attr_reader :conversation

  def transition!(attributes, action:, block_reason:)
    conversation.reload.with_lock do
      previous_control_state = conversation.control_state
      previous_assignee_id = conversation.assignee_id
      conversation.assign_attributes(attributes)
      conversation.control_version += 1
      conversation.save!
      invalidate_pending_ai!(block_reason)
      audit_transition!(action, previous_control_state, previous_assignee_id)
    end
    cancel_follow_ups!(attributes[:control_state])
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
