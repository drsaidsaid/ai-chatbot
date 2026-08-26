# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpit::NextActionPayload
  def initialize(context)
    @context = context
  end

  def to_h
    action_methods.each do |method_name|
      action = send(method_name)
      return action if action.present?
    end

    monitor_action
  end

  private

  attr_reader :context

  def action_methods
    %i[
      booked_action
      review_action
      missing_signal_action
      paused_action
      human_active_action
      closed_action
    ]
  end

  def booked_action
    return if context.latest_booking.blank?

    {
      kind: 'confirm_booking',
      label: 'Confirm call time',
      detail: context.booking_time_label(context.latest_booking)
    }
  end

  def review_action
    review = context.open_reviews.first
    return if review.blank?

    {
      kind: 'answer_review',
      label: 'Answer review request',
      detail: review.question
    }
  end

  def missing_signal_action
    return if Array(context.qualification&.missing_signals).blank?

    {
      kind: 'collect_missing_signal',
      label: 'Ask for missing signal',
      detail: context.humanize(context.qualification.missing_signals.first)
    }
  end

  def paused_action
    return unless context.conversation.ai_paused?

    {
      kind: 'resume_ai',
      label: 'Resume AI when ready',
      detail: 'AI is paused for this conversation.'
    }
  end

  def human_active_action
    return unless context.conversation.human_active? || context.conversation.handoff_requested?

    {
      kind: 'human_reply',
      label: 'Human Operator owns this conversation',
      detail: context.conversation.assignee&.name || 'Reply manually or resume AI.'
    }
  end

  def closed_action
    return unless context.conversation.closed?

    {
      kind: 'closed',
      label: 'Conversation closed',
      detail: 'No further action is scheduled.'
    }
  end

  def monitor_action
    {
      kind: 'monitor_ai',
      label: 'Let AI continue',
      detail: 'AI Employee is active and can answer the next safe question.'
    }
  end
end
