# frozen_string_literal: true

class AiLeadEmployee::KnowledgeApprovalAlertDeliveryService
  ALERT_TYPE = 'knowledge_approval'
  LockSetChanged = Class.new(StandardError)

  def initialize(knowledge_item:, enqueue: true)
    @knowledge_item = knowledge_item
    @account = knowledge_item.account
    @enqueue = enqueue
  end

  def perform
    return knowledge_item unless whatsapp_channel

    message_ids = reconcile_deliveries!
    message_ids.uniq.each { |id| SendReplyJob.perform_later(id) if enqueue }
    knowledge_item
  end

  def current_deliveries
    Array(knowledge_item.metadata['knowledge_approval_alert_deliveries']).filter_map do |delivery|
      message = account.messages.find_by(id: delivery['message_id'])
      next unless message

      delivery_payload(delivery['recipient'], message).merge(recoverable: recoverable?(message))
    end
  end

  private

  attr_reader :account, :enqueue, :knowledge_item

  def reconcile_deliveries!
    knowledge_item.reload
    locked_conversation_ids = delivery_conversation_ids
    ApplicationRecord.transaction(requires_new: true) do
      lock_alert_conversations!(locked_conversation_ids)
      knowledge_item.lock!
      knowledge_item.reload
      raise LockSetChanged unless (delivery_conversation_ids - locked_conversation_ids).empty?
      next [] unless knowledge_item.draft?

      queued_ids = []
      deliveries = recipients.map { |recipient| deliver_to_recipient(recipient, queued_ids) }
      knowledge_item.update!(metadata: knowledge_item.metadata.merge('knowledge_approval_alert_deliveries' => deliveries))
      queued_ids
    end
  rescue LockSetChanged
    retry
  end

  def delivery_conversation_ids
    message_ids = Array(knowledge_item.metadata['knowledge_approval_alert_deliveries']).filter_map { |delivery| delivery['message_id'] }
    conversation_ids = account.messages.reorder(nil).where(id: message_ids).distinct.pluck(:conversation_id)
    conversation_ids.sort
  end

  def lock_alert_conversations!(conversation_ids)
    Conversation.where(account_id: account.id, id: conversation_ids).order(:id).lock('FOR NO KEY UPDATE').load
  end

  def recipients
    AiLeadEmployee::HandoffAlertRecipients.new(account: account, alert_type: ALERT_TYPE).for(default_owner)
  end

  def deliver_to_recipient(recipient, message_ids)
    previous_delivery = delivery_for(recipient)
    message = previous_message(recipient) || create_message!(recipient)
    queue_message(message, previous_delivery, message_ids)
    delivery_payload(recipient, message)
  end

  def queue_message(message, previous_delivery, message_ids)
    return unless queueable?(message, previous_delivery)
    return unless reset_failed_delivery(message)

    message_ids << message.id
  end

  def queueable?(message, previous_delivery)
    return false if message.source_id.present?
    return true if message.failed? || previous_delivery.blank?

    message.whatsapp_outbound_delivery&.state&.in?(%w[failed canceled])
  end

  def reset_failed_delivery(message)
    delivery = message.whatsapp_outbound_delivery
    return true if delivery.blank? || delivery.pending?

    Whatsapp::KnowledgeApprovalAlertRetry.new(delivery).perform
  end

  def default_owner
    operator_id = account.reload.settings&.dig('ai_lead_employee', 'human_operator_id')
    account.users.find_by(id: operator_id)
  end

  def previous_message(recipient)
    message_id = delivery_for(recipient)&.fetch('message_id', nil)
    account.messages.find_by(id: message_id)
  end

  def delivery_for(recipient)
    Array(knowledge_item.metadata['knowledge_approval_alert_deliveries']).find { |delivery| delivery['recipient'] == recipient }
  end

  def create_message!(recipient)
    alert_conversation = AiLeadEmployee::WhatsappAlertConversation.new(
      account: account, whatsapp_channel: whatsapp_channel, recipient: recipient, alert_type: ALERT_TYPE
    ).perform
    alert_conversation.messages.create!(
      account: account, inbox: whatsapp_channel.inbox, message_type: :outgoing, content_type: :text,
      content: alert_text, private: false, additional_attributes: alert_attributes(recipient)
    )
  end

  def alert_attributes(recipient)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox', alert_type: ALERT_TYPE,
        knowledge_item_id: knowledge_item.id, alert_recipient: recipient
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

    delivery = message.whatsapp_outbound_delivery
    return delivery.state if delivery&.state&.in?(%w[failed canceled unknown])
    return 'failed' if message.failed?

    'queued'
  end

  def recoverable?(message)
    return false if message.source_id.present?

    delivery = message.whatsapp_outbound_delivery
    return Whatsapp::KnowledgeApprovalAlertRetry.new(delivery).retryable_now? if terminal_delivery?(delivery)

    recoverable_pending_message?(message, delivery)
  end

  def terminal_delivery?(delivery)
    delivery&.state&.in?(%w[failed canceled])
  end

  def recoverable_pending_message?(message, delivery)
    message.failed? && (delivery.blank? || delivery.pending?) &&
      Whatsapp::OutboundAlertAuthority.new(message).failure_code.nil?
  end

  def whatsapp_channel
    @whatsapp_channel ||= account.inboxes.where(channel_type: 'Channel::Whatsapp').order(:id).first&.channel
  end

  def alert_text
    [
      'Knowledge approval needed',
      "Open: #{knowledge_url}",
      "Title: #{knowledge_item.title}",
      "Question: #{knowledge_item.question.to_s.truncate(180)}"
    ].join("\n")
  end

  def knowledge_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{account.id}/knowledge?knowledge_item_id=#{knowledge_item.id}"
    base_url ? "#{base_url.delete_suffix('/')}#{path}" : path
  end
end
