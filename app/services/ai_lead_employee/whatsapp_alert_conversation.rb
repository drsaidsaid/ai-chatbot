# frozen_string_literal: true

class AiLeadEmployee::WhatsappAlertConversation
  def initialize(account:, whatsapp_channel:, recipient:, alert_type:)
    @account = account
    @whatsapp_channel = whatsapp_channel
    @recipient = recipient
    @alert_type = alert_type
  end

  def perform
    contact_inbox.conversations.where(account: account, inbox: whatsapp_channel.inbox).order(id: :desc).first ||
      account.conversations.create!(
        inbox: whatsapp_channel.inbox,
        contact: contact_inbox.contact,
        contact_inbox: contact_inbox,
        status: :open,
        control_state: :human_active,
        additional_attributes: {
          ai_lead_employee_alert_conversation: true,
          alert_type: alert_type
        }
      )
  end

  private

  attr_reader :account, :whatsapp_channel, :recipient, :alert_type

  def contact_inbox
    @contact_inbox ||= whatsapp_channel.inbox.contact_inboxes.find_by(source_id: recipient) ||
                       whatsapp_channel.inbox.contact_inboxes.create!(
                         contact: alert_contact,
                         source_id: recipient
                       )
  end

  def alert_contact
    return alert_bsuid_contact if recipient.match?(RegexHelper::WHATSAPP_BSUID_REGEX)

    account.contacts.find_or_create_by!(phone_number: normalized_phone_number) do |contact|
      contact.name = "WhatsApp Alert #{recipient}"
    end
  end

  def alert_bsuid_contact
    account.contacts.find_or_create_by!(identifier: "whatsapp-alert-#{recipient}") do |contact|
      contact.name = "WhatsApp Alert #{recipient}"
    end
  end

  def normalized_phone_number
    phone = recipient.to_s.delete('^+0-9')
    return phone if phone.start_with?('+')

    "+#{phone}"
  end
end
