# frozen_string_literal: true

class Conversations::ControlService
  def initialize(conversation:)
    @conversation = conversation
  end

  def human_takeover!(operator: nil)
    attributes = { control_state: :human_active, assignee_agent_bot: nil }
    attributes[:assignee] = operator if operator.present?
    transition!(attributes, action: 'human_takeover')
  end

  def pause_ai!
    transition!({ control_state: :ai_paused, assignee_agent_bot: nil }, action: 'pause_ai')
  end

  def resume_ai!
    transition!({ control_state: :ai_active, assignee_agent_bot: nil }, action: 'resume_ai')
  end

  def close!
    transition!({ control_state: :closed, assignee_agent_bot: nil }, action: 'close')
  end

  def handoff_requested!
    transition!({ control_state: :handoff_requested, assignee_agent_bot: nil }, action: 'handoff_requested')
  end

  private

  attr_reader :conversation

  def transition!(attributes, action:)
    conversation.with_lock do
      previous_control_state = conversation.control_state
      previous_assignee_id = conversation.assignee_id
      conversation.assign_attributes(attributes)
      conversation.control_version += 1
      conversation.save!
      audit_transition!(action, previous_control_state, previous_assignee_id)
    end
    cancel_follow_ups!(attributes[:control_state])
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
