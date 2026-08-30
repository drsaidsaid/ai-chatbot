# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OrchestrationIntentJob do
  let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:account) { whatsapp_channel.account }
  let(:contact) { create(:contact, account: account, phone_number: '+255700111231') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '255700111231') }
  let(:conversation) do
    create(:conversation,
           account: account,
           inbox: whatsapp_channel.inbox,
           contact: contact,
           contact_inbox: contact_inbox,
           control_state: :ai_active,
           control_version: 4,
           assignee: nil,
           status: :open)
  end
  let(:triggering_message) do
    create(:message,
           account: account,
           inbox: whatsapp_channel.inbox,
           conversation: conversation,
           sender: contact,
           message_type: :incoming,
           content: 'Do you offer AI employees?',
           source_id: 'wamid.ORCHESTRATION.TRIGGER')
  end
  let(:intent) do
    create(:ai_orchestration_intent,
           account: account,
           conversation: conversation,
           triggering_message: triggering_message,
           observed_control_version: 4)
  end

  before do
    intent
    allow(SendReplyJob).to receive(:perform_later)
  end

  it 'blocks a delayed worker after human takeover without creating outbound side effects' do
    operator = create(:user, account: account)
    Conversations::ControlService.new(conversation: conversation.reload).human_takeover!(operator: operator)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'stale_control_version')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker when the triggering message is outside the locked tenant scope' do
    other_message = create(:message, message_type: :incoming, content: 'Wrong tenant')
    # rubocop:disable Rails/SkipsModelValidations
    intent.update_columns(triggering_message_id: other_message.id)
    # rubocop:enable Rails/SkipsModelValidations

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'tenant_scope_mismatch')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker after a human reply even when control state was not updated' do
    create(:message,
           account: account,
           inbox: whatsapp_channel.inbox,
           conversation: conversation,
           sender: create(:user, account: account),
           message_type: :outgoing,
           content: 'A human has this now.')

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'human_reply_after_trigger')
    expect(conversation.messages.where(message_type: :outgoing).where.not(content: 'A human has this now.').count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker when a human is assigned even if the control version was not bumped' do
    conversation.reload.update!(assignee: create(:user, account: account))

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'assigned_to_human_operator')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker when the conversation control state no longer permits AI' do
    conversation.reload.update!(control_state: :ai_paused)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'incompatible_control_state')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker when the inbox status is no longer eligible' do
    conversation.reload.update!(status: :resolved)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'ineligible_inbox_status')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker after opt-out' do
    create(:lead_follow_up_opt_out, account: account, contact: contact, conversation: conversation, message: triggering_message)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'opted_out')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'does not create outbound work when manual resume only changes control state' do
    conversation.update!(control_state: :human_active, control_version: 5)

    Conversations::ControlService.new(conversation: conversation.reload).resume_ai!

    expect { described_class.perform_now(intent.id) }.not_to change(Message, :count)
    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'stale_control_version')
    expect(OutboxEvent.count).to eq(0)
  end

  it 'atomically records the AI decision placeholder, outbound message intent, and outbox event once under retry' do
    described_class.perform_now(intent.id)
    described_class.perform_now(intent.id)

    intent.reload
    outbound_message = intent.outbound_message
    outbox_event = OutboxEvent.find_by!(aggregate: outbound_message)

    expect(intent).to have_attributes(
      state: 'completed',
      source_references: [{ 'status' => 'pending_grounded_sources' }],
      decision: include(
        'status' => 'awaiting_grounded_answer',
        'triggering_message_id' => triggering_message.id
      )
    )
    expect(outbound_message).to have_attributes(
      account_id: account.id,
      inbox_id: whatsapp_channel.inbox.id,
      conversation_id: conversation.id,
      message_type: 'outgoing',
      content: nil,
      private: true
    )
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'orchestration_intent_id')).to eq(intent.id)
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'outbound_intent_status')).to eq('awaiting_grounded_answer')
    expect_outbox_state(outbox_event, outbound_message)
    expect(SendReplyJob).not_to have_received(:perform_later).with(outbound_message.id)
  end

  def expect_outbox_state(outbox_event, outbound_message)
    expect(outbox_event).to have_attributes(
      account_id: account.id,
      event_type: 'ai_employee.outbound_intent_recorded',
      state: 'pending'
    )
    expect(conversation.messages.outgoing.where(private: true).count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
    expect(outbox_event.aggregate).to eq(outbound_message)
  end
end
