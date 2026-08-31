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
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(SendReplyJob).to receive(:perform_later)
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
  end

  it 'blocks live processing when the launch gate is not approved' do
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(false)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'launch_gate_not_approved')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'blocks a delayed worker after human takeover without creating outbound side effects' do
    operator = create(:user, account: account)
    Conversations::ControlService.new(conversation: conversation.reload).human_takeover!(operator: operator)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'assigned_to_human_operator')
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
    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'incompatible_control_state')
    expect(OutboxEvent.count).to eq(0)
  end

  it 'atomically records qualification, a grounded AI answer, the next question, verified Source References, and outbox event once under retry' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    knowledge_item = create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    create(:qualification_question, account: account, signal: :problem, prompt: 'What problem should we solve?', position: 1)
    triggering_message.update!(content: 'Do you offer AI employees? I run an agency.')
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-1',
        model: 'openai/gpt-5.2',
        content: 'Yes, we build AI employees for qualified businesses.',
        finish_reason: 'stop'
      )
    )

    described_class.perform_now(intent.id)
    described_class.perform_now(intent.id)

    expect(provider_client).to have_received(:complete).with(hash_including(max_tokens: 64)).once

    intent.reload
    outbound_message = intent.outbound_message
    outbox_event = OutboxEvent.find_by!(aggregate: outbound_message)

    expect(intent).to have_attributes(
      state: 'completed',
      source_references: [
        include(
          'type' => 'knowledge_item',
          'id' => knowledge_item.id,
          'title' => knowledge_item.title,
          'source_kind' => 'faq',
          'status' => 'verified'
        )
      ],
      decision: include(
        'status' => 'grounded_answer',
        'triggering_message_id' => triggering_message.id
      )
    )
    expect(outbound_message).to have_attributes(
      account_id: account.id,
      inbox_id: whatsapp_channel.inbox.id,
      conversation_id: conversation.id,
      message_type: 'outgoing',
      content: "Yes, we build AI employees for qualified businesses.\n\nWhat problem should we solve?",
      private: false
    )
    expect(contact.lead_qualification).to have_attributes(quality: 'low_qualified')
    expect(contact.lead_qualification.evidence_snapshot).to include('business_type')
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'orchestration_intent_id')).to eq(intent.id)
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'outbound_intent_status')).to eq('grounded_answer')
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'source_references').first['id']).to eq(knowledge_item.id)
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'qualification')).to include(
      'quality' => 'low_qualified',
      'next_question' => 'What problem should we solve?'
    )
    expect_outbox_state(outbox_event, outbound_message)
    expect(AiLeadEmployee::OutboxDispatchJob).to have_received(:perform_later).with(outbox_event.id).once
  end

  it 'explains unsupported human requests through durable orchestration without creating a sales handoff' do
    account.update!(
      settings: {
        'ai_lead_employee' => {
          'unqualified_human_request_explanation' => 'I need to qualify the request before handing this to a Human Operator.'
        }
      }
    )
    create(:qualification_question, account: account, signal: :problem, prompt: 'What problem should we solve?', position: 1)
    create(:qualification_budget_range, account: account, min_cents: 100_000, max_cents: nil)
    triggering_message.update!(content: 'Please give me a human. My budget is $50.')

    described_class.perform_now(intent.id)

    outbound_message = intent.reload.outbound_message
    expect(outbound_message.content).to eq(
      "I need to qualify the request before handing this to a Human Operator.\n\nWhat problem should we solve?"
    )
    expect(intent).to have_attributes(state: 'completed')
    expect(contact.lead_qualification).to be_unqualified
    expect(conversation.reload).to be_ai_active
    expect(LeadHandoff.count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'creates one highly qualified handoff from current qualification evidence instead of an AI answer' do
    operator = create(:user, :administrator, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700000001' })
    account.update!(
      settings: {
        'ai_lead_employee' => {
          'human_operator_id' => operator.id,
          'alert_routes' => {
            AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE => [{ 'type' => 'assignee' }]
          }
        }
      }
    )
    triggering_message.update!(content: 'I need more leads now. I am the owner of the agency and can spend $2500.')

    described_class.perform_now(intent.id)
    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'completed', outbound_message_id: nil)
    expect(contact.lead_qualification).to be_highly_qualified
    expect(LeadHandoff.where(account: account, conversation: conversation).count).to eq(1)
    expect(conversation.reload).to have_attributes(assignee: operator, control_state: 'human_active')
    expect(SendReplyJob).to have_received(:perform_later).once
  end

  it 'creates one Review Request for unknown questions and never creates fallback answer content' do
    expect do
      described_class.perform_now(intent.id)
      intent.update!(state: :pending, blocked_reason: nil, blocked_at: nil, review_request: nil)
      described_class.perform_now(intent.id)
    end.to change(HumanReviewRequest, :count).by(1)

    review_request = intent.reload.review_request
    expect(review_request).to have_attributes(
      account_id: account.id,
      conversation_id: conversation.id,
      lead_message_id: triggering_message.id,
      reason: 'no_approved_knowledge',
      status: 'open'
    )
    expect(intent).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'creates Review Requests for conflicting, sensitive, angry, source-unverified, and stale questions without provider calls' do
    examples = {
      conflicting_knowledge: lambda {
        create(:knowledge_item, account: account, source_kind: :faq, question: triggering_message.content, answer: 'Yes.')
        create(:knowledge_item, account: account, source_kind: :faq, question: triggering_message.content, answer: 'No.')
      },
      sensitive_question: -> { triggering_message.update!(content: 'Can you give legal advice about a contract?') },
      angry_question: -> { triggering_message.update!(content: 'I am furious about this terrible service') },
      source_unverified: lambda {
        create(
          :knowledge_item,
          account: account,
          question: triggering_message.content,
          answer: 'Yes, we build AI employees.',
          metadata: { source_reference: '' }
        )
      },
      stale_knowledge: lambda {
        create(
          :knowledge_item,
          account: account,
          question: triggering_message.content,
          answer: 'Yes, we build AI employees.',
          metadata: {
            source_reference: 'expired-ai-employee-faq',
            expires_at: 1.day.ago.iso8601
          }
        )
      }
    }

    examples.each do |reason, setup|
      intent.update!(state: :pending, blocked_reason: nil, blocked_at: nil, review_request: nil)
      HumanReviewRequest.delete_all
      KnowledgeItem.where(account: account).delete_all
      triggering_message.update!(content: 'Do you offer AI employees?')
      setup.call

      expect do
        described_class.perform_now(intent.id)
        intent.update!(state: :pending, blocked_reason: nil, blocked_at: nil, review_request: nil)
        described_class.perform_now(intent.id)
      end.to change(HumanReviewRequest.where(reason: reason), :count).by(1)

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: reason.to_s)
      expect(conversation.messages.outgoing.count).to eq(0)
      expect(OutboxEvent.count).to eq(0)
    end
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'creates a Review Request when the provider declines to answer from the supplied source' do
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-review',
        model: 'openai/gpt-5.2',
        content: 'REVIEW_REQUIRED',
        finish_reason: 'stop'
      )
    )

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
    expect(intent.review_request).to have_attributes(reason: 'source_unverified', status: 'open')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 're-runs the sending boundary after provider completion before creating the outbound message' do
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    allow(provider_client).to receive(:complete) do
      create(:message,
             account: account,
             inbox: whatsapp_channel.inbox,
             conversation: conversation,
             sender: create(:user, account: account),
             message_type: :outgoing,
             content: 'A human answered while the provider was running.')
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-late',
        model: 'openai/gpt-5.2',
        content: 'Yes, we build AI employees for qualified businesses.',
        finish_reason: 'stop'
      )
    end

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'human_reply_after_trigger')
    expect(conversation.messages.outgoing.where.not(content: 'A human answered while the provider was running.').count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  it 'creates a Review Request when the provider fails after source verification' do
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    allow(provider_client).to receive(:complete).and_raise(AiLeadEmployee::AiProvider::TimeoutFailure.new)

    described_class.perform_now(intent.id)

    expect(intent.reload).to have_attributes(
      state: 'blocked',
      blocked_reason: 'provider_failure',
      failure_class: 'timeout'
    )
    expect(intent.review_request).to have_attributes(reason: 'provider_failed', status: 'open')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.count).to eq(0)
  end

  def expect_outbox_state(outbox_event, outbound_message)
    expect(outbox_event).to have_attributes(
      account_id: account.id,
      event_type: 'ai_employee.outbound_intent_recorded',
      state: 'pending'
    )
    expect(conversation.messages.outgoing.where(private: false).count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
    expect(outbox_event.aggregate).to eq(outbound_message)
  end

  def provider_client
    @provider_client ||= instance_double(AiLeadEmployee::AiProvider::OpenRouterAdapter)
  end
end
