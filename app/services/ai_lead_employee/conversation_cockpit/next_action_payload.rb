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
      closed_action
      review_action
      opted_out_action
      unresolved_booking_action
      booked_action
      booking_action
      booking_proposal_action
      missing_signal_action
      paused_action
      human_active_action
    ]
  end

  def unresolved_booking_action
    booking = context.unresolved_booking
    return unless booking

    {
      kind: 'reconcile_booking',
      label: 'Reconcile calendar result',
      detail: 'Google Calendar returned an uncertain result. Reconcile it before taking another booking action.',
      booking_id: booking.id
    }
  end

  def booked_action
    return unless context.latest_booking&.confirmed? && context.latest_booking.provider_state == 'confirmed'

    {
      kind: 'booking_confirmed',
      label: 'Call booked',
      detail: context.booking_time_label(context.latest_booking)
    }
  end

  def booking_action
    eligibility = context.booking_eligibility
    return unless eligibility&.eligible?

    agreed_starts_at = eligibility.agreement_evidence&.value&.fetch('agreed_starts_at', nil)
    return unless eligibility.agreement_evidence.message_id.present? && agreed_starts_at.present?

    {
      kind: 'book_call',
      label: 'Choose an available time',
      detail: "The Lead agreed to #{eligibility.offer.name}.",
      agreement_message_id: eligibility.agreement_evidence.message_id,
      agreed_starts_at: agreed_starts_at,
      offer_id: eligibility.offer.id
    }
  end

  def booking_proposal_action
    eligibility = context.booking_proposal_eligibility
    return unless eligibility&.eligible?

    {
      kind: 'offer_call_times',
      label: 'Offer an available time',
      detail: "Choose a live calendar slot for #{eligibility.offer.name}.",
      offer_id: eligibility.offer.id
    }
  end

  def opted_out_action
    return unless context.opted_out?

    {
      kind: 'respect_opt_out',
      label: 'Automated contact stopped',
      detail: 'This Lead asked not to receive further automated contact.'
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
