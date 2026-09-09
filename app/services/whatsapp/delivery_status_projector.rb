class Whatsapp::DeliveryStatusProjector
  def initialize(event)
    @event = event
    @status = event.payload.dig('entry', 0, 'changes', 0, 'value', 'statuses', 0)
  end

  def perform
    return :ignored unless @status && Whatsapp::MessageStatusProjector::STATUSES.include?(@status['status'])

    messages = @event.inbox.messages.where(account_id: @event.account_id, source_id: @event.provider_message_id).reorder(:id).lock.to_a
    return :awaiting_message if messages.empty?

    messages.each { |message| project(message) }
    :processed
  end

  private

  def project(message)
    sync_recipient_identifiers(message)
    Whatsapp::MessageStatusProjector.new(message: message, status: @status, provider_created_at: @event.provider_created_at).perform
  end

  def sync_recipient_identifiers(message)
    contact_inbox = message.conversation.contact_inbox
    return unless contact_inbox

    contact = @event.payload.dig('entry', 0, 'changes', 0, 'value', 'contacts', 0).to_h
    source_ids = @status.values_at('recipient_user_id', 'recipient_parent_user_id') + contact.values_at('user_id', 'parent_user_id')
    Whatsapp::IdentifierSyncService.new(contact_inbox: contact_inbox,
                                        contact: contact_inbox.contact).perform(source_ids: source_ids.compact_blank.uniq)
  end
end
