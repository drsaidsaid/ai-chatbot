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
    approve_launch_gate!

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

  it 'does not create live AI orchestration before an admin approves the launch gate' do
    message = create(:message,
                     account: whatsapp_channel.account,
                     inbox: whatsapp_channel.inbox,
                     conversation: create(:conversation, account: whatsapp_channel.account, inbox: whatsapp_channel.inbox, control_state: :ai_active),
                     message_type: :incoming,
                     content: 'Can you help?',
                     source_id: 'wamid.GATED.LEAD')

    expect(described_class.new(message: message).perform).to be_nil
    expect(AiLeadEmployee::OrchestrationIntent.count).to eq(0)
    expect(enqueued_jobs.map { |job| job[:job] }).not_to include(AiLeadEmployee::OrchestrationIntentJob)
  end

  it 'creates a Review Request without orchestration intent for unsupported media' do
    approve_launch_gate!

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

  it 'does not create live unsupported-media review automation before launch approval' do
    contact = create(:contact, account: whatsapp_channel.account, phone_number: "+#{sender_number}")
    contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: sender_number)
    conversation = create(:conversation,
                          account: whatsapp_channel.account,
                          inbox: whatsapp_channel.inbox,
                          contact: contact,
                          contact_inbox: contact_inbox,
                          control_state: :ai_active)
    message = create(:message,
                     account: whatsapp_channel.account,
                     inbox: whatsapp_channel.inbox,
                     conversation: conversation,
                     sender: contact,
                     message_type: :incoming,
                     content: I18n.t('conversations.messages.whatsapp.unsupported_message'),
                     content_attributes: { is_unsupported: true },
                     source_id: 'wamid.UNSUPPORTED.GATED')

    clear_enqueued_jobs

    expect(described_class.new(message: message).perform).to be_nil
    expect(HumanReviewRequest.count).to eq(0)
    expect(enqueued_jobs.map { |job| job[:job] }).not_to include(SendReplyJob)
  end

  it 'does not create automation while a Human Operator owns the conversation' do
    contact = create(:contact, account: whatsapp_channel.account, phone_number: "+#{sender_number}")
    contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: sender_number)
    conversation = create(:conversation,
                          account: whatsapp_channel.account,
                          inbox: whatsapp_channel.inbox,
                          contact: contact,
                          contact_inbox: contact_inbox,
                          control_state: :human_active,
                          control_version: 3)

    message = create(:message,
                     account: whatsapp_channel.account,
                     inbox: whatsapp_channel.inbox,
                     conversation: conversation,
                     sender: contact,
                     message_type: :incoming,
                     content: 'Are you available?',
                     source_id: 'wamid.HUMAN.ACTIVE.LEAD')

    expect(described_class.new(message: message).perform).to be_nil
    expect(AiLeadEmployee::OrchestrationIntent.count).to eq(0)
  end

  it 'creates a new intent only for the next lead message after explicit resume' do
    approve_launch_gate!

    contact = create(:contact, account: whatsapp_channel.account, phone_number: "+#{sender_number}")
    contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: sender_number)
    conversation = create(:conversation,
                          account: whatsapp_channel.account,
                          inbox: whatsapp_channel.inbox,
                          contact: contact,
                          contact_inbox: contact_inbox,
                          control_state: :ai_paused,
                          control_version: 4)

    expect do
      Conversations::ControlService.new(conversation: conversation).resume_ai!
    end.not_to change(Message, :count)

    resumed_message = create(:message,
                             account: whatsapp_channel.account,
                             inbox: whatsapp_channel.inbox,
                             conversation: conversation,
                             sender: contact,
                             message_type: :incoming,
                             content: 'Can you help now?',
                             source_id: 'wamid.RESUMED.LEAD')
    intent = described_class.new(message: resumed_message).perform

    expect(intent).to have_attributes(
      conversation: conversation,
      triggering_message: resumed_message,
      observed_control_version: 5,
      state: 'pending'
    )
  end

  def described_service
    Whatsapp::IncomingMessageWhatsappCloudService.new(inbox: whatsapp_channel.inbox, params: params)
  end

  def approve_launch_gate!
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(whatsapp_channel.account).and_return(true)
  end
end
