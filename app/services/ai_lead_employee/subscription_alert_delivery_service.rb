# frozen_string_literal: true

class AiLeadEmployee::SubscriptionAlertDeliveryService
  ALERT_TYPE = 'ai_subscription_action_required'

  def initialize(alert:)
    @alert = alert
    @account = alert.account
  end

  def perform
    message_ids = []
    alert.with_lock do
      recipients = owner_recipients
      deliveries = recipients.map do |recipient|
        delivery, message_id = delivery_for(recipient)
        message_ids << message_id if message_id
        delivery
      end
      alert.update!(alert_recipients: recipients, alert_deliveries: deliveries)
    end
    message_ids.each do |message_id|
      message = account.messages.find(message_id)
      message.whatsapp_outbound_delivery&.retry_subscription_alert!
      SendReplyJob.perform_later(message_id)
    end
    alert
  end

  private

  attr_reader :account, :alert

  def delivery_for(recipient)
    previous = alert.alert_deliveries.find { |delivery| delivery['recipient'] == recipient }
    message = previous_message(previous) || create_alert_message!(recipient)
    enqueue_message_id = message.source_id.blank? ? message.id : nil
    [delivery_payload(recipient, message), enqueue_message_id]
  end

  def previous_message(delivery)
    return if delivery.blank?

    account.messages.find_by(id: delivery['message_id'])
  end

  def create_alert_message!(recipient)
    conversation = AiLeadEmployee::WhatsappAlertConversation.new(
      account: account, whatsapp_channel: whatsapp_channel, recipient: recipient, alert_type: ALERT_TYPE
    ).perform
    conversation.messages.create!(
      account: account, inbox: whatsapp_channel.inbox, message_type: :outgoing, content_type: :text,
      content: alert_text, private: false, additional_attributes: additional_attributes(recipient)
    )
  end

  def additional_attributes(recipient)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox', alert_type: ALERT_TYPE,
        ai_subscription_alert_id: alert.id, alert_recipient: recipient
      }
    }
  end

  def delivery_payload(recipient, message)
    {
      recipient: recipient, status: delivery_status(message), message_id: message.id,
      conversation_id: message.conversation_id, provider_message_id: message.source_id, error: message.external_error
    }.compact
  end

  def delivery_status(message)
    return 'sent' if message.source_id.present?
    return 'failed' if message.failed?

    'queued'
  end

  def owner_recipients
    return [] unless whatsapp_channel

    Whatsapp::SubscriptionAlertRecipientResolver.for(account)
  end

  def whatsapp_channel
    @whatsapp_channel ||= account.inboxes.where(channel_type: 'Channel::Whatsapp').order(:id).first&.channel
  end

  def alert_text
    return 'AI reply allowance exhausted. Open Billing to request an approved top-up or upgrade.' if alert.allowance_exhausted?

    'AI subscription renewal is due. Open Billing to request renewal and keep automated replies active.'
  end
end
