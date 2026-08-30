# frozen_string_literal: true

class AiLeadEmployee::HandoffAlertDeliveryService
  Result = Struct.new(:message_ids_to_deliver, keyword_init: true)

  def initialize(handoff:, alert_text:, recipients:, alert_template_params: nil, enqueue: true)
    @handoff = handoff
    @alert_text = alert_text
    @recipients = recipients
    @alert_template_params = alert_template_params
    @enqueue = enqueue
  end

  def perform
    previous_deliveries = handoff.alert_deliveries.index_by { |delivery| delivery['recipient'] }
    message_ids_to_deliver = []
    deliveries = recipients.map { |recipient| alert_delivery_for(recipient, previous_deliveries[recipient], message_ids_to_deliver) }
    handoff.update!(alert_recipients: recipients, alert_deliveries: deliveries)
    Result.new(message_ids_to_deliver: message_ids_to_deliver)
  end

  private

  attr_reader :handoff, :alert_text, :recipients, :alert_template_params, :enqueue

  def alert_delivery_for(recipient, previous_delivery, message_ids_to_deliver)
    message = alert_message_from(previous_delivery)
    message ||= create_alert_message!(recipient, message_ids_to_deliver)
    retry_alert_message!(message, message_ids_to_deliver) if message.failed?

    alert_delivery_payload(recipient, message)
  end

  def alert_message_from(delivery)
    return if delivery.blank?

    account.messages.find_by(id: delivery['message_id'])
  end

  def create_alert_message!(recipient, message_ids_to_deliver)
    alert_conversation = alert_conversation_for(recipient)
    message = alert_conversation.messages.create!(
      account: account,
      inbox: whatsapp_channel.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: alert_text,
      private: false,
      additional_attributes: additional_attributes_for(recipient)
    )
    queue_delivery(message, message_ids_to_deliver)
    message
  end

  def additional_attributes_for(recipient)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox',
        handoff_id: handoff.id,
        alert_type: AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE,
        alert_recipient: recipient
      },
      template_params: alert_template_params
    }.compact
  end

  def retry_alert_message!(message, message_ids_to_deliver)
    queue_delivery(message, message_ids_to_deliver)
  end

  def queue_delivery(message, message_ids_to_deliver)
    message_ids_to_deliver << message.id
    SendReplyJob.perform_later(message.id) if enqueue
  end

  def alert_delivery_payload(recipient, message)
    {
      recipient: recipient,
      status: alert_delivery_status(message),
      message_id: message.id,
      conversation_id: message.conversation_id,
      provider_message_id: message.source_id,
      error: message.external_error
    }.compact
  end

  def alert_delivery_status(message)
    return 'sent' if message.source_id.present?
    return 'failed' if message.failed?

    'queued'
  end

  def alert_conversation_for(recipient)
    AiLeadEmployee::WhatsappAlertConversation.new(
      account: account,
      whatsapp_channel: whatsapp_channel,
      recipient: recipient,
      alert_type: AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE
    ).perform
  end

  def account
    @account ||= handoff.account
  end

  def whatsapp_channel
    @whatsapp_channel ||= handoff.conversation.inbox.channel
  end
end
