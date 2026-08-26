# frozen_string_literal: true

class Conversations::ControlService
  def initialize(conversation:)
    @conversation = conversation
  end

  def human_takeover!(operator: nil)
    attributes = { control_state: :human_active, assignee_agent_bot: nil }
    attributes[:assignee] = operator if operator.present?
    transition!(attributes)
  end

  def pause_ai!
    transition!(control_state: :ai_paused, assignee_agent_bot: nil)
  end

  def resume_ai!
    transition!(control_state: :ai_active, assignee_agent_bot: nil)
  end

  def close!
    transition!(control_state: :closed, assignee_agent_bot: nil)
  end

  def handoff_requested!
    transition!(control_state: :handoff_requested, assignee_agent_bot: nil)
  end

  private

  attr_reader :conversation

  def transition!(attributes)
    conversation.with_lock do
      conversation.assign_attributes(attributes)
      conversation.control_version += 1
      conversation.save!
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
end
