# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Orchestration::IntentProcessor do
  let!(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:account) { channel.account }
  let(:contact) { create(:contact, account: account, phone_number: '+255700444321') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700444321') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active, control_version: 2, assignee: nil, status: :open)
  end
  let(:triggering_message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: message, source_id: 'wamid.R11')
  end
  let(:intent) do
    create(:ai_orchestration_intent, account: account, conversation: conversation,
                                     triggering_message: triggering_message, observed_control_version: 2)
  end
  let(:message) { 'Do you integrate with Acme CRM?' }

  before do
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
  end

  it 'records a real Review and truthful acknowledgment for a relevant unknown without asking a sales question' do
    offer = create_offer(qualification_mode: 'enabled', questions: [question('business_type', 'What business do you run?')])
    conversation.update!(offer: offer)

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', status: 'open')
    expect(intent.outbound_message.content).to eq(
      'I do not have an approved answer for that yet. I have recorded your question for the team to review.'
    )
    expect(intent.outbound_message.content).not_to include('What business do you run?')
    expect(LeadQualification.where(contact: contact)).to be_empty
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'sets a polite boundary for an unrelated request without creating Review or qualification evidence' do
    triggering_message.update!(content: 'Who won the football match?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    expect(LeadQualification.where(contact: contact)).to be_empty
  end

  it 'treats the same external how-to question according to the approved Business scope' do
    triggering_message.update!(content: 'How do I repair my bicycle?')
    create(:knowledge_item, account: account, question: 'How can I grow my coaching business?',
                            answer: 'Use the approved coaching programme.')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'answers an external how-to question when approved Business knowledge covers that work' do
    triggering_message.update!(content: 'How do I repair my bicycle?')
    offer = create_offer
    conversation.update!(offer: offer)
    create(
      :knowledge_document,
      account: account,
      title: 'Bicycle repair workshop',
      body: 'Bring the bicycle to our repair workshop for an inspection.',
      general_question_access: false,
      offer_ids: [offer.id]
    )
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r11-bike-answer', model: connection.model,
        content: 'Bring the bicycle to our repair workshop for an inspection.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('Bring the bicycle to our repair workshop for an inspection.')
  end

  it 'sets a boundary for an arbitrary informational question outside the approved Business scope' do
    triggering_message.update!(content: 'What is the capital of France?')
    create(:knowledge_item, account: account, question: 'How can I grow my coaching business?',
                            answer: 'Use the approved coaching programme.')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'does not treat a personal-preference question as Business scope merely because it says your' do
    triggering_message.update!(content: 'What is your favorite animal?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  ['What is open source software?', 'Who delivered the keynote speech?'].each do |unrelated_question|
    it "keeps an unrelated question outside Review despite an ambiguous verb: #{unrelated_question}" do
      triggering_message.update!(content: unrelated_question)
      conversation.reload

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    end
  end

  {
    'Do you accept American Express?' => :english,
    'Can I pay in installments?' => :english,
    'Do you deliver to Zanzibar?' => :english,
    'Je, mnakubali M-Pesa?' => :swahili,
    'Mnasafirisha hadi Arusha?' => :swahili
  }.each do |unknown_question, language|
    it "records Review for a plausible #{language} Business exchange: #{unknown_question}" do
      triggering_message.update!(content: unknown_question)
      conversation.reload

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
      expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', status: 'open')
      expect(intent.outbound_message.content).to include('recorded your question for the team to review')
      expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
    end
  end

  it 'records Review for an unknown detail in the configured Offer scope' do
    offer = create_offer
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Does Growth coaching include weekend delivery?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', status: 'open')
  end

  it 'records a typed answer to the current configured Offer question even without fixed qualification words' do
    configured_question = question('clinic_count', 'How many clinics?').merge('answer_type' => 'text')
    offer = create_offer(qualification_mode: 'enabled', questions: [configured_question])
    conversation.update!(offer: offer)
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content: "Thanks.\n\nHow many clinics?",
      additional_attributes: {
        'ai_lead_employee' => {
          'qualification' => {
            'offer_id' => offer.id,
            'configuration_version' => offer.configuration_version,
            'next_question' => 'How many clinics?',
            'next_question_key' => 'clinic_count'
          }
        }
      }
    )
    triggering_message.update!(content: 'Five')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    evidence = QualificationEvidence.find_by!(account: account, contact: contact, offer: offer, field_key: 'clinic_count')
    expect(evidence.value).to include('typed_value' => 'Five', 'polarity' => 'positive')
    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('Thanks for those details.')
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'records an explicit human-help Review without inserting a qualification question' do
    triggering_message.update!(content: 'Please let me speak to a human.')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'human_requested')
    expect(intent.review_request).to have_attributes(reason: 'human_requested', status: 'open')
    expect(intent.outbound_message.content).to eq('I have recorded your request for human help.')
    expect(LeadQualification.where(contact: contact)).to be_empty
  end

  it 'answers selected Offer knowledge before adding the current configured progression' do
    offer = create_offer(next_step: { 'kind' => 'enquiry', 'prompt' => 'Would you like to discuss Growth coaching?' })
    conversation.update!(offer: offer)
    create(
      :knowledge_item,
      account: account,
      question: message,
      answer: 'Growth coaching integrates with Acme CRM.',
      metadata: { 'source_reference' => 'growth-acme-v1', 'offer_ids' => [offer.id], 'language' => 'english' }
    )
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r11-answer', model: connection.model, content: 'Growth coaching integrates with Acme CRM.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq(
      "Growth coaching integrates with Acme CRM.\n\nWould you like to discuss Growth coaching?"
    )
    expect(intent.source_references.first).to include('offer_id' => offer.id, 'offer_configuration_version' => offer.configuration_version)
    expect(intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'offer_context')).to include(
      'scope' => 'offer_answer', 'offer_id' => offer.id, 'configuration_version' => offer.configuration_version
    )
  end

  it 'rejects an amount introduced by provider output and records Review instead' do
    create(:knowledge_item, account: account, question: message, answer: 'The integration is available.')
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r11-unsupported-price', model: connection.model, content: 'The integration costs $20.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
    expect(intent.review_request).to have_attributes(reason: 'source_unverified')
    expect(intent.outbound_message.content).to include('recorded your question for the team to review')
  end

  def provider_client
    @provider_client ||= instance_double(AiLeadEmployee::AiProvider::MeteredClient)
  end

  def question(key, prompt)
    { 'key' => key, 'meaning' => key.humanize, 'answer_type' => 'text', 'prompt' => prompt, 'position' => 0,
      'enabled' => true, 'required' => true, 'purpose' => 'fit' }
  end

  def create_offer(qualification_mode: 'disabled', questions: [], next_step: { 'kind' => 'answer_only' })
    AiLeadEmployee::Offer.create!(
      account: account, name: 'Growth coaching', currency: 'USD', enabled: true,
      configuration: {
        'qualification_mode' => qualification_mode,
        'next_step' => next_step,
        'questions' => questions,
        'budget_ranges' => [],
        'rules' => [],
        'score_weights' => {},
        'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
      }
    )
  end
end
