# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::WhatsappAutoReplyService do
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
  let(:incoming_message) do
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: 'Please give me a human.'
    )
  end

  before do
    allow(Meta::Whatsapp::OutboundMessageSender).to receive(:new)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
  end

  it 'records an orchestration intent without direct WhatsApp delivery side effects' do
    expect do
      described_class.new(
        conversation: conversation,
        incoming_message: incoming_message,
        provider_message_payload: { type: 'text' }
      ).perform
    end.to change(AiLeadEmployee::OrchestrationIntent, :count).by(1)
                                                              .and not_change(Message.outgoing, :count)

    expect(Meta::Whatsapp::OutboundMessageSender).not_to have_received(:new)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
end
