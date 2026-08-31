# frozen_string_literal: true

class AiLeadEmployee::HumanReviewRequestService
  Result = Struct.new(:request, :created, keyword_init: true)

  ALERT_TYPE = 'human_review_request'
  ALERT_TEXT_PREFIX = 'Human review needed'

  def initialize(conversation:, lead_message:, reason:, enqueue_alerts: true)
    @conversation = conversation
    @lead_message = lead_message
    @reason = reason
    @enqueue_alerts = enqueue_alerts
  end

  def perform
    request, created = find_or_create_request

    deliver_alerts!(request) if created
    Result.new(request: request, created: created)
  rescue ActiveRecord::RecordNotUnique
    Result.new(
      request: conversation.account.human_review_requests.find_by!(
        conversation: conversation,
        lead_message: lead_message,
        reason: reason
      ),
      created: false
    )
  end

  private

  attr_reader :conversation, :lead_message, :reason, :enqueue_alerts

  def find_or_create_request
    request = nil
    created = false

    HumanReviewRequest.transaction(requires_new: true) do
      request = conversation.account.human_review_requests.find_or_initialize_by(
        conversation: conversation,
        lead_message: lead_message,
        reason: reason
      )
      created = request.new_record?
      request.assign_attributes(question: lead_message.content.to_s) if created
      request.save!
    end

    [request, created]
  end

  def deliver_alerts!(request)
    recipients = alert_recipients
    previous_deliveries = request.alert_deliveries.index_by { |delivery| delivery['recipient'] }
    deliveries = recipients.map { |recipient| alert_delivery_for(request, recipient, previous_deliveries[recipient]) }
    request.update!(alert_recipients: recipients, alert_deliveries: deliveries)
  end

  def alert_delivery_for(request, recipient, previous_delivery)
    message = alert_message_from(previous_delivery)
    message ||= create_alert_message!(request, recipient)
    SendReplyJob.perform_later(message.id) if enqueue_alerts && (previous_delivery.blank? || message.failed?)

    {
      recipient: recipient,
      status: alert_delivery_status(message),
      message_id: message.id,
      conversation_id: message.conversation_id,
      provider_message_id: message.source_id,
      error: message.external_error
    }.compact
  end

  def alert_message_from(delivery)
    return if delivery.blank?

    message_id = Integer(delivery['message_id'], exception: false)
    return if message_id.blank?

    conversation.account.messages.find_by(id: message_id)
  end

  def create_alert_message!(request, recipient)
    alert_conversation = AiLeadEmployee::WhatsappAlertConversation.new(
      account: conversation.account,
      whatsapp_channel: whatsapp_channel,
      recipient: recipient,
      alert_type: ALERT_TYPE
    ).perform
    alert_conversation.messages.create!(
      account: conversation.account,
      inbox: whatsapp_channel.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: alert_text,
      private: false,
      additional_attributes: alert_additional_attributes(request, recipient)
    )
  end

  def alert_additional_attributes(request, recipient)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox',
        review_request_id: request.id,
        alert_type: ALERT_TYPE,
        alert_recipient: recipient
      }
    }
  end

  def alert_text
    "#{ALERT_TEXT_PREFIX}: #{lead_message.content.to_s.truncate(120)}"
  end

  def alert_recipients
    Array(conversation.account.settings&.dig('ai_review_alert_recipients')).filter_map(&:presence).uniq
  end

  def whatsapp_channel
    @whatsapp_channel ||= conversation.inbox.channel
  end

  def alert_delivery_status(message)
    return 'sent' if message.source_id.present?
    return 'failed' if message.failed?

    'queued'
  end
end
