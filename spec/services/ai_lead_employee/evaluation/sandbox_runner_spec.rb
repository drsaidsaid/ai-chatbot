# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Evaluation::SandboxRunner do
  include ActiveJob::TestHelper

  let(:account) { create(:account, settings: { ai_review_alert_recipients: ['255700000001'] }) }
  let(:admin) { create(:user, :administrator, account: account) }

  before do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-eval',
        model: 'openai/gpt-5.2',
        content: 'Yes, we build AI employees for qualified businesses.',
        finish_reason: 'stop'
      )
    )
    allow(SendReplyJob).to receive(:perform_later)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'runs the real orchestration path in a rollback and persists an inspectable decision snapshot' do
    message_count = Message.count
    outbox_event_count = OutboxEvent.count
    review_request_count = HumanReviewRequest.count
    result = nil

    expect do
      result = described_class.new(account: account, user: admin, scenario_key: 'approved_answer').perform
    end.to change(AiLeadEmployee::EvaluationRun, :count).by(1)

    expect(Message.count).to eq(message_count)
    expect(OutboxEvent.count).to eq(outbox_event_count)
    expect(HumanReviewRequest.count).to eq(review_request_count)
    expect(result.run).to be_completed
    expect(result.run.steps.first).to include(
      'selected_answer' => "Yes, we build AI employees for qualified businesses.\n\nWhat problem are you trying to solve right now?",
      'review_request' => nil,
      'handoff_decision' => 'continue_ai',
      'booking_decision' => 'not_eligible',
      'follow_up_decision' => 'schedule_incomplete_qualification'
    )
    expect(result.run.steps.first['source_references'].first).to include('type' => 'knowledge_item', 'status' => 'verified')
    expect(result.run.steps.first.dig('qualification', 'quality')).to eq('low_qualified')
    expect(result.run.provider_snapshot).to include('model' => 'openai/gpt-5.2')
    expect(result.run.prompt_version).to eq(AiLeadEmployee::Evaluation::SandboxRunner::PROMPT_VERSION)

    expect(SendReplyJob).not_to have_received(:perform_later)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'records controlled-claim review requirements without faking a manual pass' do
    result = described_class.new(account: account, user: admin, scenario_key: 'controlled_claim_requires_review').perform

    expect(result.run).to be_completed
    expect(result.run).to be_pending_review
    expect(result.run.steps.first['review_request']).to be_present
    expect(result.run.steps.first['selected_answer']).to be_nil
    expect(result.run.metrics.fetch('serious_issue_count')).to eq(0)
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'runs every required reusable scenario without persisted WhatsApp delivery side effects' do
    message_count = Message.count
    outbox_event_count = OutboxEvent.count
    review_request_count = HumanReviewRequest.count
    runs = AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.map do |scenario_key|
      described_class.new(account: account, user: admin, scenario_key: scenario_key).perform.run
    end

    expect(runs.map(&:scenario_key)).to match_array(AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys)
    expect(runs).to all(be_completed)
    expect(runs.flat_map(&:steps).flat_map { |step| step.fetch('checks', []) }).to all(include('passed' => true))
    expect(Message.count).to eq(message_count)
    expect(OutboxEvent.count).to eq(outbox_event_count)
    expect(HumanReviewRequest.count).to eq(review_request_count)
    expect(SendReplyJob).not_to have_received(:perform_later)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'expects a safe Swahili language question to receive a policy-backed response' do # rubocop:disable RSpec/MultipleExpectations
    result = described_class.new(account: account, user: admin, scenario_key: 'safe_swahili_language_question').perform
    step = result.run.steps.first

    expect(result.run).to be_completed
    expect(step['selected_answer']).to be_present
    expect(step['selected_answer']).to include('Kiswahili')
    expect(step['review_request']).to include('reason' => 'no_approved_knowledge')
    expect(step['review_request_reason']).to eq('no_approved_knowledge')
    expect(step['blocked_reason']).to be_nil
    expect(step['handoff_decision']).to eq('continue_ai')
    expect(result.run.metrics.fetch('serious_issue_count')).to eq(0)
  end

  it 'expects an unknown safe question to receive a bounded fallback instead of silence' do # rubocop:disable RSpec/MultipleExpectations
    result = described_class.new(account: account, user: admin, scenario_key: 'unknown_safe_question').perform
    step = result.run.steps.first

    expect(result.run).to be_completed
    expect(step['selected_answer']).to be_present
    expect(step['selected_answer']).to include('I do not have an approved answer for that yet')
    expect(step['review_request']).to include('reason' => 'no_approved_knowledge')
    expect(step['review_request_reason']).to eq('no_approved_knowledge')
    expect(step['blocked_reason']).to be_nil
    expect(step['handoff_decision']).to eq('continue_ai')
    expect(result.run.metrics.fetch('serious_issue_count')).to eq(0)
  end

  it 'surfaces configured language preference in persisted step snapshots' do
    result = described_class.new(account: account, user: admin, scenario_key: 'safe_swahili_language_question').perform

    expect(result.run.steps.first['language']).to eq('sw')
  end

  def provider_client
    @provider_client ||= instance_double(AiLeadEmployee::AiProvider::OpenRouterAdapter)
  end
end
