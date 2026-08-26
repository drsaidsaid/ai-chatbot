# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::HumanReviewRequestService do
  let(:account) { create(:account, settings: { ai_review_alert_recipients: ['255700000001'] }) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      provider_config: { 'phone_number_id' => 'phone-id', 'api_key' => 'secret' },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, control_state: :ai_active) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: channel.inbox, content: 'Can you guarantee results?') }

  before do
    stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .to_return(status: 200, body: { messages: [{ id: 'alert-message-id' }] }.to_json)
  end

  it 'creates one open review request and sends the configured WhatsApp alert' do
    result = described_class.new(
      conversation: conversation,
      lead_message: message,
      reason: 'no_approved_knowledge'
    ).perform

    expect(result.request).to be_open
    expect(result.request.question).to eq('Can you guarantee results?')
    expect(result.request.alert_recipients).to eq(['255700000001'])
    expect(result.request.alert_deliveries).to contain_exactly(
      include('recipient' => '255700000001', 'status' => 'sent', 'provider_message_id' => 'alert-message-id')
    )
    expect(
      a_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
        .with(body: hash_including(to: '255700000001', type: 'text'))
    ).to have_been_made.once

    expect do
      described_class.new(
        conversation: conversation,
        lead_message: message,
        reason: 'no_approved_knowledge'
      ).perform
    end.not_to change(HumanReviewRequest, :count)
  end
end
