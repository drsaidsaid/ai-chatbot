# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Meta::Whatsapp::OutboundMessageSender do
  let(:access_token) { 'test_key' }
  let(:graph_version) { 'v23.0' }
  let(:account) { create(:account) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: {
        'api_key' => access_token,
        'phone_number_id' => '123456789',
        'business_account_id' => '444555666',
        'source' => 'embedded_signup'
      }
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

  around do |example|
    with_modified_env(META_GRAPH_API_VERSION: graph_version, &example)
  end

  before do
    stub_request(:post, "https://graph.facebook.com/#{graph_version}/123456789/messages")
      .with(
        body: {
          messaging_product: 'whatsapp',
          to: '255712345678',
          type: 'text',
          text: { body: 'Thanks for contacting us.' }
        },
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: {
          messaging_product: 'whatsapp',
          messages: [{ id: 'wamid.OUTBOUND123' }]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'sends a controlled text reply through Meta and records the external message id' do
    message = described_class.new(
      conversation: conversation,
      content: 'Thanks for contacting us.',
      expected_control_version: 0
    ).perform

    expect(message).to be_outgoing
    expect(message).to be_sent
    expect(message.content).to eq('Thanks for contacting us.')
    expect(message.source_id).to eq('wamid.OUTBOUND123')
    expect(message.inbox).to eq(channel.inbox)
    expect(message.conversation).to eq(conversation)
  end

  it 'blocks a delayed AI send after a Human Operator takes control' do
    conversation.update!(control_state: :human_active, control_version: 1)

    expect do
      described_class.new(
        conversation: conversation,
        content: 'Thanks for contacting us.',
        expected_control_version: 0
      ).perform
    end.to raise_error(described_class::BlockedByControlState)
      .and not_change(Message, :count)
  end
end
