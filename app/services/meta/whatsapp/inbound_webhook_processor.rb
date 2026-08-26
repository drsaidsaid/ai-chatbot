# frozen_string_literal: true

class Meta::Whatsapp::InboundWebhookProcessor
  class UnknownPhoneNumber < StandardError; end

  def initialize(payload:)
    @payload = payload.with_indifferent_access
  end

  def perform
    message_changes.each do |change|
      process_change(change)
    end
  end

  private

  attr_reader :payload

  def message_changes
    payload.fetch(:entry, []).flat_map { |entry| entry.fetch(:changes, []) }.select { |change| change[:field] == 'messages' }
  end

  def process_change(change)
    value = change.fetch(:value)
    channel = channel_for!(value.dig(:metadata, :phone_number_id))
    contacts_by_wa_id = value.fetch(:contacts, []).index_by { |contact| contact[:wa_id].to_s }

    value.fetch(:messages, []).each do |message_payload|
      process_message(channel, contacts_by_wa_id, message_payload.with_indifferent_access)
    end

    value.fetch(:statuses, []).each do |status_payload|
      process_status(channel, status_payload.with_indifferent_access)
    end
  end

  def process_message(channel, contacts_by_wa_id, message_payload)
    return unless %w[text audio voice].include?(message_payload[:type].to_s)

    reply_context = nil
    MetaWhatsappWebhookEvent.transaction do
      event = create_message_event(channel, message_payload)
      next if event.processed_at.present?

      context = message_context(channel, contacts_by_wa_id, message_payload)
      incoming_message = create_incoming_message!(context, message_payload)
      reply_context = [context[:conversation], incoming_message, message_payload]
      event.update!(conversation: context[:conversation], processed_at: Time.current)
    end

    send_ai_employee_reply!(*reply_context) if reply_context.present?
  end

  def process_status(channel, status_payload)
    status = status_payload[:status].to_s
    return unless Message.statuses.key?(status)

    MetaWhatsappWebhookEvent.transaction do
      event = create_status_event(channel, status_payload, status)
      next if event.processed_at.present?

      message = update_message_status(channel, status_payload, status)
      event.update!(conversation: message&.conversation, processed_at: Time.current)
    end
  end

  def channel_for!(phone_number_id)
    channel = Channel::Whatsapp.find_by("provider_config ->> 'phone_number_id' = ?", phone_number_id.to_s)
    raise UnknownPhoneNumber if channel.blank?

    channel
  end

  def create_message_event(channel, message_payload)
    MetaWhatsappWebhookEvent.create_or_find_by!(provider_event_id: message_payload[:id]) do |record|
      assign_event_context(record, channel)
      record.event_kind = "message.#{message_payload[:type]}"
      record.payload = message_payload
    end
  end

  def create_status_event(channel, status_payload, status)
    MetaWhatsappWebhookEvent.create_or_find_by!(provider_event_id: status_event_id(status_payload)) do |record|
      assign_event_context(record, channel)
      record.event_kind = "status.#{status}"
      record.payload = status_payload
    end
  end

  def assign_event_context(record, channel)
    record.account = channel.account
    record.inbox = channel.inbox
    record.channel_whatsapp = channel
  end

  def message_context(channel, contacts_by_wa_id, message_payload)
    contact_payload = contacts_by_wa_id[message_payload[:from].to_s]&.with_indifferent_access || {}
    contact = find_or_create_contact(channel.account, contact_payload, message_payload)
    contact_inbox = find_or_create_contact_inbox(channel.inbox, contact, message_payload)

    {
      account: channel.account,
      inbox: channel.inbox,
      contact: contact,
      conversation: find_or_create_conversation(channel.account, channel.inbox, contact, contact_inbox)
    }
  end

  def create_incoming_message!(context, message_payload)
    Message.create!(
      account: context[:account],
      inbox: context[:inbox],
      conversation: context[:conversation],
      sender: context[:contact],
      message_type: :incoming,
      content_type: :text,
      content: incoming_message_content(message_payload),
      content_attributes: incoming_message_content_attributes(message_payload),
      source_id: message_payload[:id],
      created_at: Time.zone.at(message_payload[:timestamp].to_i)
    )
  end

  def incoming_message_content(message_payload)
    return message_payload.dig(:text, :body) if message_payload[:type] == 'text'

    'Unsupported WhatsApp voice note received.'
  end

  def incoming_message_content_attributes(message_payload)
    return {} if message_payload[:type] == 'text'

    {
      is_unsupported: true,
      data: {
        provider: 'meta_whatsapp',
        provider_media_type: message_payload[:type],
        provider_media_id: message_payload.dig(message_payload[:type], :id),
        v1_handling: 'request_text'
      }
    }
  end

  def send_ai_employee_reply!(conversation, incoming_message, message_payload)
    AiLeadEmployee::WhatsappAutoReplyService.new(
      conversation: conversation,
      incoming_message: incoming_message,
      provider_message_payload: message_payload
    ).perform
  end

  def update_message_status(channel, status_payload, status)
    message = Message.find_by(account: channel.account, inbox: channel.inbox, source_id: status_payload[:id])
    message&.update!(status: status)
    message
  end

  def find_or_create_contact(account, contact_payload, message_payload)
    wa_id = message_payload[:from].to_s
    phone_number = "+#{wa_id}"

    Contact.find_or_initialize_by(account: account, phone_number: phone_number).tap do |contact|
      contact.identifier ||= wa_id
      contact.name = contact_payload.dig(:profile, :name).presence || contact.name || phone_number
      contact.save!
    end
  end

  def find_or_create_contact_inbox(inbox, contact, message_payload)
    ContactInbox.find_or_create_by!(inbox: inbox, source_id: message_payload[:from].to_s) do |contact_inbox|
      contact_inbox.contact = contact
    end
  end

  def find_or_create_conversation(account, inbox, contact, contact_inbox)
    contact_inbox.current_conversation || Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      status: :open,
      additional_attributes: { channel: 'meta_whatsapp' },
      last_activity_at: Time.current
    )
  end

  def status_event_id(status_payload)
    [status_payload[:id], status_payload[:status], status_payload[:timestamp]].join(':')
  end
end
