# frozen_string_literal: true

class Whatsapp::KnowledgeApprovalAlertRetry
  def initialize(delivery)
    @delivery = delivery
  end

  def perform
    ApplicationRecord.transaction do
      Conversation.where(id: delivery.conversation_id).lock('FOR NO KEY UPDATE').load
      delivery.conversation.reload
      authority = Whatsapp::OutboundAlertAuthority.new(delivery.message)
      authority.lock_record!
      delivery.with_lifecycle { retry_locked(authority) }
    end
  end

  def retryable_now?
    retryable_delivery? && Whatsapp::OutboundAlertAuthority.new(delivery.message).failure_code.nil?
  end

  private

  attr_reader :delivery

  def retry_locked(authority)
    return false unless retryable_delivery?

    failure = authority.failure_code
    if failure
      delivery.update!(state: :canceled, failure_code: failure)
      delivery.publish!
      return false
    end

    delivery.update!(state: :pending, owner_token: nil, lease_expires_at: nil, failure_code: nil)
    delivery.message.update!(status: :sent, external_error: nil)
    delivery.publish!
    true
  end

  def retryable_delivery?
    delivery.state.in?(%w[failed canceled]) &&
      delivery.attempts < Whatsapp::OutboundDelivery::MAX_CLAIM_ATTEMPTS &&
      delivery.message.reload.source_id.blank? &&
      delivery.message.additional_attributes.dig('ai_lead_employee', 'alert_type') ==
        AiLeadEmployee::KnowledgeApprovalAlertDeliveryService::ALERT_TYPE
  end
end
