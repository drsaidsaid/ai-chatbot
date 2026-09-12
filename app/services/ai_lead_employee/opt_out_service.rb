# frozen_string_literal: true

class AiLeadEmployee::OptOutService
  def initialize(conversation:, message:)
    @conversation = conversation
    @message = message
  end

  def perform
    return unless opt_out_message?

    ApplicationRecord.transaction do
      conversations = conversation.account.conversations.where(contact_id: conversation.contact_id).order(:id).lock('FOR NO KEY UPDATE').to_a
      cancellation = AiLeadEmployee::AutomationCancellation.new(conversations: conversations)
      cancellation.lock_offers!
      opt_out = LeadFollowUpOptOut.find_or_initialize_by(account: conversation.account, contact: conversation.contact)
      opt_out.automation_cancellation_owner = cancellation
      opt_out.update!(conversation: conversation, message: message,
                      reason: AiLeadEmployee::AutomatedContactConsent::STOP_REASON, opted_out_at: Time.current)
      cancellation.cancel!(reason: 'opted_out')
      opt_out
    end
  end

  def opt_out_message?
    AiLeadEmployee::AutomatedContactConsent.withdrawal?(message.content)
  end

  private

  attr_reader :conversation, :message
end
