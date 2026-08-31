# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Meta::Whatsapp::OutboundMessageSender do
  let(:account) { create(:account) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:contact) { create(:contact, account: account, phone_number: '+255712345678') }
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, contact: contact, source_id: '255712345678') }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      control_state: :ai_active,
      control_version: 0
    )
  end

  before do
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
  end

  it 'is quarantined from production delivery in favor of the canonical CE WhatsApp path' do
    expect do
      described_class.new(
        conversation: conversation,
        content: 'Thanks for contacting us.',
        expected_control_version: 0
      ).perform
    end.to raise_error(
      described_class::RetiredPath,
      'Use Message, SendReplyJob, and Whatsapp::SendOnWhatsappService for WhatsApp delivery'
    ).and not_change(Message, :count)

    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
end
