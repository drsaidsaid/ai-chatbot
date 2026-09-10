# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review acknowledgment delivery', type: :request do
  self.use_transactional_tests = false

  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:account) { channel.account }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, control_state: :ai_active, control_version: 4,
                          assignee: nil, status: :open)
  end
  let(:incoming) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: conversation.contact,
                     message_type: :incoming, content: 'I have a complaint. Please connect me to a human.', provider_created_at: Time.current)
  end
  let(:intent) do
    create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: incoming, observed_control_version: 4)
  end
  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  before do
    clean_committed_fixtures
    approve_launch!
  end

  after { clean_committed_fixtures }

  it 'commits one blocked Review acknowledgment before enqueue and accepts it once under competing outbox workers', :aggregate_failures do
    committed_at_enqueue = []
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later) do |event_id|
      committed_at_enqueue << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          event = OutboxEvent.find(event_id)
          message = event.aggregate
          message.whatsapp_outbound_delivery.pending? && HumanReviewRequest.exists?(
            id: message.additional_attributes.dig('ai_lead_employee', 'review_request_id')
          )
        end
      end.value
    end
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    event = OutboxEvent.find_by!(idempotency_key: "ai-outbound/#{intent.id}")
    request = stub_request(:post, provider_url).to_return do
      sleep 0.05
      { status: 200, body: { messages: [{ id: 'wamid.EMERGENCY.ACK.ONCE' }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
    end

    concurrently { AiLeadEmployee::OutboxDispatchJob.perform_now(event.id) }

    expect(committed_at_enqueue).to eq([true])
    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'angry_question')
    expect(intent.review_request).to have_attributes(reason: 'angry_question', status: 'open')
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(intent.outbound_message.whatsapp_outbound_delivery.reload).to have_attributes(state: 'accepted',
                                                                                         provider_message_id: 'wamid.EMERGENCY.ACK.ONCE')
    expect(intent.outbound_message.reload.content_attributes['whatsapp_provider_status']).to be_nil
    expect(event.reload.state).to eq('delivered')
    expect(request).to have_been_requested.once
  end

  it 'recovers a committed acknowledgment after enqueue failure without repeating orchestration or provider work', :aggregate_failures do
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later).and_raise('Synthetic queue unavailable')
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_call_original

    expect { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }.to raise_error(RuntimeError, 'Synthetic queue unavailable')
    event = OutboxEvent.find_by!(idempotency_key: "ai-outbound/#{intent.id}")
    expect(event.state).to eq('pending')
    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'angry_question', attempts: 1)
    request = stub_request(:post, provider_url).to_return(
      status: 200, body: '{"messages":[{"id":"wamid.EMERGENCY.ACK.RECOVERED"}]}', headers: { 'Content-Type' => 'application/json' }
    )

    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    2.times { AiLeadEmployee::OutboxDispatchJob.perform_now(event.id) }

    expect(intent.reload.attempts).to eq(1)
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(1)
    expect(event.reload.state).to eq('delivered')
    expect(request).to have_been_requested.once
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  %w[complaint provider_failure].each do |route|
    it "keeps the #{route} Review, acknowledgment and operator alert committed when the alert queue fails", :aggregate_failures do
      account.update!(settings: account.settings.merge('ai_review_alert_recipients' => ['255700111290']))
      if route == 'provider_failure'
        incoming.update!(content: 'Do you offer AI employees?')
        create(:knowledge_item, account: account, question: incoming.content)
        create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
        stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(
          status: 402, body: '{"error":{"message":"Synthetic provider failure"}}'
        )
      end
      visible_at_enqueue = []
      allow(SendReplyJob).to receive(:perform_later) do |message_id|
        visible_at_enqueue << Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            alert = Message.find_by(id: message_id)
            alert.present? && OutboxEvent.exists?(idempotency_key: "ai-outbound/#{intent.id}")
          end
        end.value
        raise 'Synthetic alert queue unavailable'
      end

      expect { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }.to raise_error(RuntimeError, 'Synthetic alert queue unavailable')

      expect(visible_at_enqueue).to eq([true])
      expect(intent.reload.state).to eq('blocked')
      expect(intent.review_request&.reason).to eq(route == 'complaint' ? 'angry_question' : 'provider_failed')
      expect(intent.outbound_message&.whatsapp_outbound_delivery&.state).to eq('pending')
      expect(conversation.messages.outgoing.count).to eq(1)
      expect(OutboxEvent.find_by(idempotency_key: "ai-outbound/#{intent.id}")&.state).to eq('pending')
      alert_id = intent.review_request&.alert_deliveries&.first&.fetch('message_id')
      expect(Whatsapp::OutboundDelivery.find_by(message_id: alert_id)&.state).to eq('pending')
    end
  end

  %w[takeover assignment opt_out launch_withdrawal window_expiry].each do |change|
    it "cancels the recorded acknowledgment after #{change} without treating its Review as operator-alert authority", :aggregate_failures do
      AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
      event = OutboxEvent.find_by!(idempotency_key: "ai-outbound/#{intent.id}")
      request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.TOO.LATE"}]}')

      case change
      when 'takeover'
        Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin)
      when 'assignment'
        conversation.update!(assignee: admin)
      when 'opt_out'
        create(:lead_follow_up_opt_out, account: account, contact: conversation.contact, conversation: conversation)
      when 'launch_withdrawal'
        AiLeadEmployee::LaunchGate.for(account).update!(approved_at: nil)
      when 'window_expiry'
        incoming.update!(provider_created_at: 25.hours.ago)
      end
      2.times { AiLeadEmployee::OutboxDispatchJob.perform_now(event.id) }

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'angry_question')
      expect(intent.outbound_message.whatsapp_outbound_delivery.reload.state).to eq('canceled')
      expect(event.reload.state).to eq('canceled')
      expect(conversation.messages.outgoing.count).to eq(1)
      expect(HumanReviewRequest.where(conversation: conversation).count).to eq(1)
      expect(request).not_to have_been_requested
    end
  end

  it 'acknowledges an exhausted expired claim once and commits its operator alert without another model attempt', :aggregate_failures do
    account.update!(settings: account.settings.merge('ai_review_alert_recipients' => ['255700111290']))
    intent.update!(state: :processing, owner_token: 'abandoned', attempts: 3, lease_expires_at: 1.minute.ago)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_call_original
    visible_at_enqueue = []
    allow(SendReplyJob).to receive(:perform_later) do |message_id|
      visible_at_enqueue << Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Message.exists?(message_id) && OutboxEvent.exists?(idempotency_key: "ai-outbound/#{intent.id}")
        end
      end.value
    end

    2.times { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }

    expect(intent.reload).to have_attributes(state: 'failed', failure_class: 'claim_recovery_exhausted', attempts: 3)
    expect(intent.review_request).to have_attributes(reason: 'provider_failed', status: 'open')
    expect(intent.outbound_message&.content).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
    expect(intent.outbound_message&.whatsapp_outbound_delivery&.state).to eq('pending')
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(1)
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
    expect(intent.review_request&.alert_deliveries&.size).to eq(1)
    expect(visible_at_enqueue).to eq([true])
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  %w[live revoked].each do |claim_state|
    it "does not acknowledge an exhausted #{claim_state} claim", :aggregate_failures do
      intent.update!(state: :processing, owner_token: 'existing-worker', attempts: 3,
                     lease_expires_at: claim_state == 'live' ? 1.minute.from_now : 1.minute.ago)
      Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin) if claim_state == 'revoked'
      allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_call_original

      2.times { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }

      expect(intent.reload.attempts).to eq(3)
      expect(conversation.messages.outgoing.count).to eq(0)
      expect(HumanReviewRequest.where(conversation: conversation).count).to eq(0)
      expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(0)
      expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
    end
  end

  it 'records uncertain acceptance without resending or recursively acknowledging the delivery Review', :aggregate_failures do
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    event = OutboxEvent.find_by!(idempotency_key: "ai-outbound/#{intent.id}")
    request = stub_request(:post, provider_url).to_timeout

    2.times { AiLeadEmployee::OutboxDispatchJob.perform_now(event.id) }
    SendReplyJob.perform_now(intent.reload.outbound_message_id)
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'angry_question')
    expect(intent.review_request.reason).to eq('angry_question')
    expect(intent.outbound_message.whatsapp_outbound_delivery.reload.state).to eq('unknown')
    expect(event.reload.state).to eq('unknown')
    expect(HumanReviewRequest.where(conversation: conversation, lead_message: intent.outbound_message, reason: :delivery_unknown).count).to eq(1)
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
    expect(request).to have_been_requested.once
  end

  it 'creates one Review acknowledgment when independent orchestration workers compete for the same claim', :aggregate_failures do
    intent_id = intent.id

    concurrently { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent_id) }

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'angry_question', attempts: 1)
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
  end

  it 'keeps the replacement claim failure and acknowledgment when an expired worker returns later', :aggregate_failures do
    incoming.update!(content: 'Do you offer AI employees?')
    create(:knowledge_item, account: account, question: incoming.content)
    create(:ai_provider_connection, account: account, model: 'openai/gpt-4o-mini')
    started = Queue.new
    release = Queue.new
    attempts = 0
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do
      attempts += 1
      if attempts == 1
        started << true
        release.pop
        { status: 402, body: '{"error":{"message":"Synthetic expired-worker failure"}}' }
      else
        { status: 401, body: '{"error":{"message":"Synthetic replacement-worker failure"}}' }
      end
    end
    intent_id = intent.id
    first_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent_id) }
    end
    Timeout.timeout(20) { started.pop }
    intent.reload.update!(lease_expires_at: 1.second.ago)

    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent_id)
    release << true
    first_worker.value

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failure', failure_class: 'authentication_failure',
                                             attempts: 2)
    expect(intent.review_request).to have_attributes(reason: 'provider_failed', status: 'open')
    expect(intent.outbound_message.content).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
    expect(conversation.messages.outgoing.count).to eq(1)
    expect(HumanReviewRequest.where(conversation: conversation).count).to eq(1)
    expect(OutboxEvent.where(idempotency_key: "ai-outbound/#{intent.id}").count).to eq(1)
    expect(request).to have_been_requested.twice
  ensure
    release << true if release
    first_worker&.join(20)
  end

  def concurrently(&)
    start = Queue.new
    workers = Array.new(2) do
      Thread.new do
        start.pop
        ActiveRecord::Base.connection_pool.with_connection(&)
      end
    end
    workers.size.times { start << true }
    workers.each(&:value)
  ensure
    workers&.each(&:join)
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end

  def approve_launch!
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |scenario_key|
      create(:ai_lead_employee_evaluation_run, :reviewed_pass, account: account, user: admin, scenario_key: scenario_key)
    end
    evaluator = AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: 3)
    evaluator.approve!(user: admin, notes: 'Synthetic emergency acknowledgment checks only')
  end
end
