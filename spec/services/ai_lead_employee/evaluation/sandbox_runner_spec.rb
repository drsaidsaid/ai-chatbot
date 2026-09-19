# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Evaluation::SandboxRunner do
  include ActiveJob::TestHelper

  let(:account) { create(:account, settings: { ai_review_alert_recipients: ['255700000001'] }) }
  let(:admin) { create(:user, :administrator, account: account) }
  let!(:provider_connection) { create(:ai_provider_connection, account: account) }

  before do |example|
    unless example.metadata[:api_only_account]
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    end
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-eval',
        model: 'openai/gpt-5.2',
        content: 'Yes, we build AI employees for qualified businesses.',
        finish_reason: 'stop',
        configuration_version: provider_connection.configuration_version
      )
    )
    allow(SendReplyJob).to receive(:perform_later)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new) unless example.metadata[:api_only_account]
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
      'selected_answer' => 'Yes, we build AI employees for qualified businesses.',
      'review_request' => nil,
      'handoff_decision' => 'continue_ai',
      'booking_decision' => 'not_eligible',
      'follow_up_decision' => 'not_eligible',
      'qualification' => nil
    )
    expect(result.run.steps.first['source_references'].first).to include('type' => 'knowledge_item', 'status' => 'verified')
    expect(result.run.provider_snapshot).to include('model' => 'openai/gpt-5.2')
    expect(result.run.prompt_version).to eq(AiLeadEmployee::Evaluation::SandboxRunner::PROMPT_VERSION)

    expect(SendReplyJob).not_to have_received(:perform_later)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'runs the real no-send runtime against the exact published setup source and Offer revision' do
    offer = account.qualification_offers.create!(name: 'No qualification product', currency: 'TZS')
    document = account.knowledge_documents.new
    document.save_draft!(attributes: { title: 'Published setup', body: 'This product helps small shops.',
                                       general_question_access: false, offer_ids: [offer.id] }, editor: admin)
    document.publish!(editor: admin)
    source = AiLeadEmployee::BusinessSetupSource.create!(
      account: account, offer: offer, title: 'Published setup', source_type: 'document', body: 'This product helps small shops.', proposal: {},
      status: :published, version: 2, published_offer_version: offer.configuration_version, published_at: Time.current,
      published_by: admin, knowledge_document: document
    )

    result = described_class.new(
      account: account, user: admin, scenario_key: 'business_setup_context', business_setup_source: source,
      question: 'Which small shops does this product help?'
    ).perform

    expect(result.run).to be_completed
    expect(result.run.configuration_snapshot.fetch('business_setup_source')).to include(
      'id' => source.id, 'offer_id' => offer.id, 'version' => 2,
      'published_offer_version' => offer.configuration_version
    )
    expect(result.run.messages.first).to include('body' => 'Which small shops does this product help?')
    expect(result.run.steps.first.fetch('source_references')).to include(
      include('type' => 'knowledge_document', 'id' => document.id, 'status' => 'verified')
    )
    expect(provider_client).to have_received(:complete).with(
      hash_including(messages: include(hash_including(content: include('Approved source answer: This product helps small shops.'))))
    )
    expect(SendReplyJob).not_to have_received(:perform_later)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end

  it 'uses normal inbound retrieval after a corrected setup supersedes the old Knowledge Document' do
    offer = account.qualification_offers.create!(name: 'Corrected inventory service', currency: 'TZS', enabled: true)
    old_document = account.knowledge_documents.new
    old_document.save_draft!(attributes: { title: 'Old inventory setup', body: 'Inventory service uses old guidance.',
                                           general_question_access: false, offer_ids: [offer.id] }, editor: admin)
    old_document.publish!(editor: admin)
    old_document.archive!(editor: admin)
    corrected_document = account.knowledge_documents.new
    corrected_document.save_draft!(
      attributes: { title: 'Corrected inventory setup', body: 'Inventory service uses corrected stock guidance.',
                    general_question_access: false, offer_ids: [offer.id] }, editor: admin
    )
    corrected_document.publish!(editor: admin)
    source = AiLeadEmployee::BusinessSetupSource.create!(
      account: account, offer: offer, title: 'Corrected inventory setup', source_type: 'document',
      body: corrected_document.body, proposal: {}, status: :published, version: 2,
      published_offer_version: offer.configuration_version, published_at: Time.current,
      published_by: admin, knowledge_document: corrected_document
    )

    result = described_class.new(
      account: account, user: admin, scenario_key: 'business_setup_context', business_setup_source: source,
      question: 'What corrected stock guidance does the inventory service use?'
    ).perform

    expect(result.run).to be_completed
    expect(result.run.steps.first.fetch('source_references')).to include(
      include('type' => 'knowledge_document', 'id' => corrected_document.id, 'status' => 'verified')
    )
    expect(result.run.steps.first.fetch('source_references')).not_to include(include('id' => old_document.id))
  end

  it 'fails a delayed run when its published Offer revision changes before runtime admission' do
    offer = account.qualification_offers.create!(name: 'Changing service', currency: 'TZS')
    source = AiLeadEmployee::BusinessSetupSource.create!(
      account: account, offer: offer, title: 'Published setup', source_type: 'document', body: 'Service details', proposal: {},
      status: :published, version: 1, published_offer_version: offer.configuration_version, published_at: Time.current
    )
    runner = described_class.new(account: account, user: admin, scenario_key: 'approved_answer', business_setup_source: source)
    offer.update!(configuration_version: offer.configuration_version + 1)

    result = runner.perform

    expect(result.run).to be_failed
    expect(result.run.steps.first).to include('error' => 'Business setup source is no longer current')
    expect(SendReplyJob).not_to have_received(:perform_later)
  end

  it 'records controlled-claim review requirements without faking a manual pass' do
    result = described_class.new(account: account, user: admin, scenario_key: 'controlled_claim_requires_review').perform

    expect(result.run).to be_completed
    expect(result.run).to be_pending_review
    expect(result.run.steps.first['review_request']).to be_present
    expect(result.run.steps.first['selected_answer']).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
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
    failed_runs = runs.reject(&:completed?).map do |run|
      error = run.steps.first
      [run.scenario_key, error['error_class'], error['error']]
    end
    expect(failed_runs).to be_empty
    expect(runs.flat_map(&:steps).flat_map { |step| step.fetch('checks', []) }).to all(include('passed' => true))
    expect(Message.count).to eq(message_count)
    expect(OutboxEvent.count).to eq(outbox_event_count)
    expect(HumanReviewRequest.count).to eq(review_request_count)
    expect(SendReplyJob).not_to have_received(:perform_later)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'answers a safe Swahili language question without creating Review' do # rubocop:disable RSpec/MultipleExpectations
    result = described_class.new(account: account, user: admin, scenario_key: 'safe_swahili_language_question').perform
    step = result.run.steps.first

    expect(result.run).to be_completed
    expect(step['selected_answer']).to be_present
    expect(step['selected_answer']).to include('Kiswahili')
    expect(step['review_request']).to be_nil
    expect(step['review_request_reason']).to be_nil
    expect(step['blocked_reason']).to be_nil
    expect(step['handoff_decision']).to eq('continue_ai')
    expect(result.run.metrics.fetch('serious_issue_count')).to eq(0)
  end

  it 'expects an unknown safe question to receive a bounded fallback instead of silence' do # rubocop:disable RSpec/MultipleExpectations
    result = described_class.new(account: account, user: admin, scenario_key: 'unknown_safe_question').perform
    clarification_step, review_step = result.run.steps

    expect(result.run).to be_completed
    expect(clarification_step['selected_answer']).to eq('Are you asking about this business or one of its Offers?')
    expect(clarification_step['review_request']).to be_nil
    expect(review_step['selected_answer']).to include('I do not have an approved answer for that yet')
    expect(review_step['review_request']).to include('reason' => 'no_approved_knowledge')
    expect(review_step['review_request_reason']).to eq('no_approved_knowledge')
    expect(review_step['blocked_reason']).to eq('no_approved_knowledge')
    expect(review_step['handoff_decision']).to eq('blocked')
    expect(result.run.metrics.fetch('serious_issue_count')).to eq(0)
  end

  it 'surfaces configured language preference in persisted step snapshots' do
    result = described_class.new(account: account, user: admin, scenario_key: 'safe_swahili_language_question').perform

    expect(result.run.steps.first['language']).to eq('sw')
  end

  it 'persists a contextual Knowledge Document test through the normal evaluation run path' do
    document = create(
      :knowledge_document,
      account: account,
      title: 'Agency automation guide',
      body: 'Agency automation connects inquiries to an AI employee workflow.'
    )
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-document-eval', model: provider_connection.model,
        content: 'Agency automation connects inquiries to an AI employee workflow.', finish_reason: 'stop',
        configuration_version: provider_connection.configuration_version
      )
    )

    result = described_class.new(
      account: account,
      user: admin,
      scenario_key: 'knowledge_document_context',
      knowledge_document: document,
      question: 'How does agency automation connect inquiries?'
    ).perform

    expect(result.run).to be_persisted
    expect(result.run).to have_attributes(
      scenario_key: 'knowledge_document_context',
      scenario_name: 'Knowledge document: Agency automation guide'
    )
    expect(result.run.steps.first['source_references'].first).to include(
      'type' => 'knowledge_document',
      'id' => document.id
    )
    expect(result.run.knowledge_snapshot.fetch('documents')).to include(
      include('id' => document.id, 'source_reference' => document.source_reference)
    )
  end

  it 'runs a contextual document test for an API-only account without contacting Meta', :api_only_account do
    api_channel = Channel::Api.create!(account: account, additional_attributes: {})
    Inbox.create!(account: account, channel: api_channel, name: 'API-only evaluation inbox')
    document = create(
      :knowledge_document,
      account: account,
      title: 'API-only automation guide',
      body: 'API-only automation connects inquiries to an evaluation workflow.'
    )
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'provider-response-api-only-document-eval', model: provider_connection.model,
        content: 'API-only automation connects inquiries to an evaluation workflow.', finish_reason: 'stop',
        configuration_version: provider_connection.configuration_version
      )
    )

    result = described_class.new(
      account: account,
      user: admin,
      scenario_key: 'knowledge_document_context',
      knowledge_document: document,
      question: 'How does API-only automation connect inquiries?'
    ).perform

    expect(result.run).to be_completed
    expect(result.run.steps.first['source_references'].first).to include(
      'type' => 'knowledge_document',
      'id' => document.id
    )
    expect(a_request(:any, %r{\Ahttps://graph\.facebook\.com/})).not_to have_been_made
    expect(Channel::Whatsapp.where(account: account)).to be_empty
  end

  def provider_client
    @provider_client ||= instance_double(AiLeadEmployee::AiProvider::MeteredClient)
  end
end
