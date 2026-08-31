# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::FollowUpDeliveryService do
  let(:account) { create(:account) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: {
        'api_key' => 'test-key',
        'phone_number_id' => '111222333',
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
      control_version: 4
    )
  end
  let(:qualification) { create(:lead_qualification, account: account, contact: contact, quality: :low_qualified) }
  let(:follow_up) do
    create(
      :lead_follow_up,
      account: account,
      contact: contact,
      conversation: conversation,
      lead_qualification: qualification,
      content: 'Can you share your budget?',
      control_version: 4,
      scheduled_at: Time.current
    )
  end

  before do
    stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .to_return(
        status: 200,
        body: { messages: [{ id: 'wamid.FOLLOW_UP' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'records a pending follow-up once through the durable outbox path' do
    expect do
      described_class.new(follow_up: follow_up).perform
    end.to have_enqueued_job(AiLeadEmployee::OutboxDispatchJob)

    described_class.new(follow_up: follow_up.reload).perform

    expect(follow_up.reload).to be_pending
    expect(follow_up.message.content).to eq('Can you share your budget?')
    expect(follow_up.message.additional_attributes.fetch('ai_lead_employee')).to include(
      'delivery_boundary' => 'outbox',
      'delivery_type' => 'qualification_follow_up'
    )
    expect(Message.outgoing.where(conversation: conversation).count).to eq(1)
    expect(OutboxEvent.pending.where(idempotency_key: "ai-follow-up/#{follow_up.id}").count).to eq(1)
    expect(WebMock).not_to have_requested(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
  end

  it 'cancels a late job after control state changes' do
    conversation.update!(control_state: :human_active, control_version: 5)

    described_class.new(follow_up: follow_up).perform

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('incompatible_control_state')
    expect(Message.outgoing.where(conversation: conversation)).to be_empty
  end

  it 'cancels a late job after the conversation is resolved' do
    conversation.update!(status: :resolved)

    described_class.new(follow_up: follow_up).perform

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('incompatible_control_state')
    expect(Message.outgoing.where(conversation: conversation)).to be_empty
  end

  it 'cancels a late job after opt-out' do
    create(:lead_follow_up_opt_out, account: account, contact: contact, conversation: conversation)

    described_class.new(follow_up: follow_up).perform

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('follow_up_opted_out')
  end

  it 'does not send internal notes as follow-ups' do
    internal_note = create(:message, account: account, conversation: conversation, inbox: channel.inbox, message_type: :outgoing, private: true)
    follow_up.update!(message: internal_note)

    described_class.new(follow_up: follow_up.reload).perform

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('internal_note')
    expect(WebMock).not_to have_requested(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
  end

  it 'reschedules an early delivery job without creating a message' do
    follow_up.update!(scheduled_at: 1.hour.from_now)

    expect do
      described_class.new(follow_up: follow_up).perform
    end.to have_enqueued_job(AiLeadEmployee::FollowUpDeliveryJob)

    expect(follow_up.reload).to be_pending
    expect(Message.outgoing.where(conversation: conversation)).to be_empty
  end
end
