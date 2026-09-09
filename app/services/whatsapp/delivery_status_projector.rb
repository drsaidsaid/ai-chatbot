class Whatsapp::DeliveryStatusProjector
  SUCCESS_ORDER = { 'sent' => 0, 'delivered' => 1, 'read' => 2 }.freeze
  SAFE_DELIVERY_ERROR = 'WhatsApp could not deliver this message. Check the connection before retrying.'.freeze

  def initialize(event)
    @event = event
    @status = event.payload.dig('entry', 0, 'changes', 0, 'value', 'statuses', 0)
  end

  def perform
    return :ignored unless @status && (SUCCESS_ORDER.keys + ['failed']).include?(@status['status'])

    messages = @event.inbox.messages.where(account_id: @event.account_id, source_id: @event.provider_message_id).reorder(:id).lock.to_a
    return :awaiting_message if messages.empty?

    messages.each { |message| project(message) }
    :processed
  end

  private

  def project(message)
    sync_recipient_identifiers(message)
    return unless may_advance?(message)

    message.status = @status['status']
    attributes = message.content_attributes.merge('whatsapp_delivery_timestamp' => @event.provider_created_at&.to_i)
    if @status['status'] == 'failed'
      attributes['whatsapp_delivery_error_code'] = @status.dig('errors', 0, 'code').to_s[/\A\d+\z/]
      attributes['external_error'] = SAFE_DELIVERY_ERROR
    else
      attributes.delete('external_error')
      attributes.delete('whatsapp_delivery_error_code')
    end
    message.update!(content_attributes: attributes)
  end

  def sync_recipient_identifiers(message)
    contact_inbox = message.conversation.contact_inbox
    return unless contact_inbox

    contact = @event.payload.dig('entry', 0, 'changes', 0, 'value', 'contacts', 0).to_h
    source_ids = @status.values_at('recipient_user_id', 'recipient_parent_user_id') + contact.values_at('user_id', 'parent_user_id')
    Whatsapp::IdentifierSyncService.new(contact_inbox: contact_inbox,
                                        contact: contact_inbox.contact).perform(source_ids: source_ids.compact_blank.uniq)
  end

  def may_advance?(message)
    incoming = @status['status']
    existing = message.status
    return false if existing == 'read'
    return incoming == 'read' if existing == 'delivered'

    !stale_failure_transition?(message, incoming, existing)
  end

  def stale_failure_transition?(message, incoming, existing)
    existing_time = message.content_attributes['whatsapp_delivery_timestamp'].to_i
    (incoming == 'failed' && @event.provider_created_at.to_i < existing_time) ||
      (existing == 'failed' && incoming == 'sent' && @event.provider_created_at.to_i <= existing_time)
  end
end
