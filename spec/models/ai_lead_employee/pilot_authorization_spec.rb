# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::PilotAuthorization do
  let(:account) { create(:account) }
  let(:provider) { create(:ai_provider_connection, account: account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700000001') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active)
  end
  let(:message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Authorized question')
  end
  let!(:authorization) do
    described_class.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: conversation.control_version, provider_configuration_version: provider.configuration_version,
      max_attempts: 2, max_spend_usd: 1, provider_limit_usd: 1, provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
                                 verification_digest: 'sha256:response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
  end

  it 'matches only the exact Business Account, Inbox, Lead, Conversation, recipient, and revisions' do
    other_contact = create(:contact, account: account)
    other_contact_message = message_for(account: account, channel: channel, contact: other_contact, source_id: '255700000002')
    other_channel = create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false)
    other_inbox_message = message_for(account: account, channel: other_channel, contact: contact, source_id: '255700000003')
    other_account = create(:account)
    create(:ai_provider_connection, account: other_account)
    other_account_channel = create(
      :channel_whatsapp, account: other_account, sync_templates: false, validate_provider_config: false
    )
    other_account_message = message_for(account: other_account, channel: other_account_channel,
                                        contact: create(:contact, account: other_account), source_id: '255700000004')

    expect(described_class.current_for(message: message)).to eq(authorization)
    expect([other_contact_message, other_inbox_message, other_account_message].map do |candidate|
      described_class.current_for(message: candidate)
    end).to all(be_nil)
  end

  it 'allows only one active authorization for a Conversation' do
    expect { authorization.dup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  def message_for(account:, channel:, contact:, source_id:)
    contact_inbox = create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: source_id)
    conversation = create(:conversation, account: account, inbox: channel.inbox, contact: contact,
                                         contact_inbox: contact_inbox, control_state: :ai_active)
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Other question')
  end
end
