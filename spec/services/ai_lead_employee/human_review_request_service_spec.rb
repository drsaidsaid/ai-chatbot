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
    allow(SendReplyJob).to receive(:perform_later)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'creates one open review request and queues a canonical WhatsApp alert message' do
    result = described_class.new(
      conversation: conversation,
      lead_message: message,
      reason: 'no_approved_knowledge'
    ).perform

    expect(result.request).to be_open
    expect(result.request.question).to eq('Can you guarantee results?')
    expect(result.request.alert_recipients).to eq(['255700000001'])
    expect(result.request.alert_deliveries).to contain_exactly(
      include('recipient' => '255700000001', 'status' => 'queued', 'message_id' => be_present)
    )
    alert_message = account.messages.find(result.request.alert_deliveries.first['message_id'])
    expect(alert_message.additional_attributes.dig('ai_lead_employee', 'delivery_boundary')).to eq('outbox')
    expect(alert_message.additional_attributes.dig('ai_lead_employee', 'review_request_id')).to eq(result.request.id)
    expect(SendReplyJob).to have_received(:perform_later).with(alert_message.id).once
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)

    expect do
      described_class.new(
        conversation: conversation,
        lead_message: message,
        reason: 'no_approved_knowledge'
      ).perform
    end.not_to change(HumanReviewRequest, :count)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'can persist the review request without queueing alert delivery for simulations' do
    result = described_class.new(
      conversation: conversation,
      lead_message: message,
      reason: 'sensitive_question',
      enqueue_alerts: false
    ).perform

    expect(result.request).to be_open
    expect(result.request.alert_deliveries).to contain_exactly(
      include('recipient' => '255700000001', 'status' => 'queued', 'message_id' => be_present)
    )
    alert_message = account.messages.find(result.request.alert_deliveries.first['message_id'])
    expect(SendReplyJob).not_to have_received(:perform_later).with(alert_message.id)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
end
