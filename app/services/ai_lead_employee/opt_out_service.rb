# frozen_string_literal: true

class AiLeadEmployee::OptOutService
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
      reason: AiLeadEmployee::AutomatedContactConsent::STOP_REASON,
      opted_out_at: Time.current
    )
    AiLeadEmployee::FollowUpScheduler.cancel_pending_for!(conversation: conversation, reason: 'follow_up_opted_out')
    opt_out
  end

  def opt_out_message?
    AiLeadEmployee::AutomatedContactConsent.withdrawal?(message.content)
  end

  private

  attr_reader :conversation, :message
end
