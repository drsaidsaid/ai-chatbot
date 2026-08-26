# frozen_string_literal: true

class AiLeadEmployee::OptOutService
  OPT_OUT_PATTERN = /\A\s*(stop|unsubscribe|opt\s*out|do not contact|don't contact|no more messages|acha kunitumia)\b/i

  def initialize(conversation:, message:)
    @conversation = conversation
    @message = message
  end

  def perform
    return unless opt_out_message?

    opt_out = LeadFollowUpOptOut.find_or_initialize_by(account: conversation.account, contact: conversation.contact)
    opt_out.update!(
      conversation: conversation,
      message: message,
      reason: 'lead_requested_opt_out',
      opted_out_at: Time.current
    )
    AiLeadEmployee::FollowUpScheduler.cancel_pending_for!(conversation: conversation, reason: 'follow_up_opted_out')
    close_qualification!
    opt_out
  end

  def opt_out_message?
    message.content.to_s.match?(OPT_OUT_PATTERN)
  end

  private

  attr_reader :conversation, :message

  def close_qualification!
    qualification = conversation.contact.lead_qualification
    return if qualification.blank?

    qualification.update!(follow_up_state: :closed, last_evaluated_at: Time.current)
  end
end
