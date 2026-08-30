# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OrchestrationIntentRecorder do
  include ActiveJob::TestHelper

  let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:sender_number) { '255700111230' }
  let(:message_id) { 'wamid.ORCHESTRATION.INTENT' }
  let(:params) do
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            contacts: [{ profile: { name: 'Intent Lead' }, wa_id: sender_number }],
            messages: [{
              from: sender_number,
              id: message_id,
              text: { body: 'Can you qualify my leads?' },
              timestamp: '1787740800',
              type: 'text'
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end

  before do
    whatsapp_channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome to AI Lead Employee.')
    stub_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
      .with(
        body: {
          messaging_product: 'whatsapp',
          context: nil,
          to: sender_number,
          text: { body: 'Welcome to AI Lead Employee.' },
          type: 'text'
        }.to_json
      )
      .to_return(
        status: 200,
        body: { messages: [{ id: 'wamid.GREETING.ORCHESTRATION.SENT' }] }.to_json,
        headers: { 'content-type' => 'application/json' }
      )
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
  end

  it 'records one tenant-scoped intent after the inbound message and channel greeting commit' do
    perform_enqueued_jobs(only: SendReplyJob) do
      described_service.perform
      described_service.perform
    end

    conversation = whatsapp_channel.inbox.conversations.first
    inbound_message = conversation.messages.incoming.find_by!(source_id: message_id)
    greeting = conversation.messages.template.find_by!(content: 'Welcome to AI Lead Employee.')
    intent = AiLeadEmployee::OrchestrationIntent.find_by!(triggering_message: inbound_message)

    expect(conversation.messages.order(:created_at, :id).pluck(:content)).to eq(
      ['Can you qualify my leads?', 'Welcome to AI Lead Employee.']
    )
    expect(greeting.source_id).to eq('wamid.GREETING.ORCHESTRATION.SENT')
    expect(intent).to have_attributes(
      account_id: whatsapp_channel.account_id,
      conversation_id: conversation.id,
      observed_control_version: conversation.control_version,
      state: 'pending'
    )
    expect(intent.idempotency_key).to eq("ai-orchestration/#{whatsapp_channel.account_id}/#{conversation.id}/#{inbound_message.id}/0")
    expect(AiLeadEmployee::OrchestrationIntent.count).to eq(1)
    expect(enqueued_jobs.map { |job| job[:job] }).to include(AiLeadEmployee::OrchestrationIntentJob)
  end

  it 'creates a Review Request without orchestration intent for unsupported media' do
    unsupported_params = params.deep_dup
    message = unsupported_params.dig(:entry, 0, :changes, 0, :value, :messages, 0)
    message.delete(:text)
    message[:type] = 'unsupported'
    message[:errors] = [{ code: 131_060, title: 'Unsupported message type' }]

    Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: whatsapp_channel.inbox, params: unsupported_params).perform

    expect(AiLeadEmployee::OrchestrationIntent.count).to eq(0)
    review_request = HumanReviewRequest.find_by!(reason: :unsupported_media)
    expect(review_request.question).to eq(I18n.t('conversations.messages.whatsapp.unsupported_message'))
    expect(review_request.conversation).to eq(whatsapp_channel.inbox.conversations.first)
  end

  def described_service
    Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: whatsapp_channel.inbox, params: params)
  end
end
