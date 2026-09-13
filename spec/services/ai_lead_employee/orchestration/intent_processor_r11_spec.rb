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

    confirmation_intent = clarify_and_confirm_scope!(offer.name)

    expect(confirmation_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(confirmation_intent.review_request).to have_attributes(
      reason: 'no_approved_knowledge', status: 'open', lead_message_id: triggering_message.id
    )
    expect(confirmation_intent.outbound_message.content).to eq(
      'I do not have an approved answer for that yet. I have recorded your question for the team to review.'
    )
    expect(confirmation_intent.outbound_message.content).not_to include('What business do you run?')
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

  it 'clarifies an external how-to question when the available scope is ambiguous' do
    triggering_message.update!(content: 'How do I repair my bicycle?')
    create(:knowledge_item, account: account, question: 'How can I grow my coaching business?',
                            answer: 'Use the approved coaching programme.')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('Are you asking about this business or one of its Offers?')
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
    account.update!(name: 'France')
    conversation.update!(offer: create_offer(name: 'Capital'))
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
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'What is your favorite animal?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  {
    'Do you accept American Express?' => [:english, 'yes'],
    'Can I pay in installments?' => [:english, 'your programme'],
    'Do you deliver to Zanzibar?' => [:english, 'Growth coaching'],
    'Je, mnakubali M-Pesa?' => [:swahili, 'ndiyo'],
    'Mnasafirisha hadi Arusha?' => [:swahili, 'Ofa hii']
  }.each do |unknown_question, (language, confirmation)|
    it "records Review for a plausible #{language} Business exchange: #{unknown_question}" do
      offer = create_offer
      conversation.update!(offer: offer)
      triggering_message.update!(content: unknown_question)
      conversation.reload

      confirmation_intent = clarify_and_confirm_scope!(confirmation)

      expect(confirmation_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
      expect(confirmation_intent.review_request).to have_attributes(
        reason: 'no_approved_knowledge', status: 'open', lead_message_id: triggering_message.id
      )
      expected_copy = language == :swahili ? 'Nimeweka swali lako' : 'recorded your question'
      expect(confirmation_intent.outbound_message.content).to include(expected_copy)
      expect(conversation.reload.additional_attributes).not_to have_key(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
      expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
    end
  end

  it 'uses a recent trusted Offer answer to resolve an obvious follow-up without clarification' do
    offer = create_offer(name: 'Pulse')
    conversation.update!(offer: offer)
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content: 'Pulse classes are available online.',
      additional_attributes: {
        'ai_lead_employee' => { 'offer_context' => { 'offer_id' => offer.id } }
      }
    )
    triggering_message.update!(content: 'Are there weekend classes?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', lead_message_id: triggering_message.id)
  end

  it 'sets a boundary for a named third-party commerce question' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'How much does Netflix cost?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  [
    'What is open source software?',
    'Who delivered the keynote speech?',
    'Can I pay my electricity bill in installments?',
    'Can I book a flight?',
    'What book should I read?',
    'What is the train schedule?',
    'Where do I register to vote?'
  ].each do |ambiguous_question|
    it "clarifies third-party commerce or general activity without creating Review: #{ambiguous_question}" do
      triggering_message.update!(content: ambiguous_question)
      conversation.reload

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(intent.outbound_message.content).to eq('Are you asking about this business or one of its Offers?')

      conversation.update!(offer: create_offer(name: 'Pulse'))
      repeated_intent = process_followup(ambiguous_question)

      expect(repeated_intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(repeated_intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
      expect(conversation.reload.additional_attributes).not_to have_key(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
    end
  end

  [
    'How long does it take?',
    'Are there weekend classes?',
    'Can I attend offline?',
    'Is parking available?',
    'Can I join online?',
    'Je, ninaweza kujiunga mtandaoni?'
  ].each do |contextual_question|
    it "records Review for an unknown within the selected Offer context: #{contextual_question}" do
      offer = create_offer(name: 'Pulse')
      conversation.update!(offer: offer)
      triggering_message.update!(content: contextual_question)

      confirmation_intent = clarify_and_confirm_scope!(offer.name)

      expect(confirmation_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
      expect(confirmation_intent.review_request).to have_attributes(
        reason: 'no_approved_knowledge', status: 'open', lead_message_id: triggering_message.id
      )
    end
  end

  it 'matches a configured one-word Offer name without requiring two overlapping tokens' do
    create_offer(name: 'Pulse')
    triggering_message.update!(content: 'Does Pulse include weekend classes?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(intent.review_request).to have_attributes(reason: 'no_approved_knowledge', status: 'open')
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

  def clarify_and_confirm_scope!(confirmation)
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!

    process_followup(confirmation, expected_scope: triggering_message.content)
  end

  def expect_scope_clarification!
    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expected = if AiLeadEmployee::LanguageDetector.detect(triggering_message.content) == :swahili
                 'Je, unauliza kuhusu biashara hii au mojawapo ya Ofa zake?'
               else
                 'Are you asking about this business or one of its Offers?'
               end
    expect(intent.outbound_message.content).to eq(expected)
    context = conversation.reload.additional_attributes.fetch(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
    expect(context).to include('question' => triggering_message.content, 'message_id' => triggering_message.id)
  end

  def process_followup(content, expected_scope: nil)
    followup, followup_intent = followup_records(content)
    expect_followup_classification!(followup, expected_scope)
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    followup_intent
  end

  def followup_records(content)
    followup = create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: contact,
      message_type: :incoming,
      content: content,
      source_id: "wamid.R11.scope.#{SecureRandom.hex(6)}"
    )
    followup_intent = create(
      :ai_orchestration_intent,
      account: account,
      conversation: conversation,
      triggering_message: followup,
      observed_control_version: conversation.control_version
    )
    [followup, followup_intent]
  end

  def expect_followup_classification!(followup, expected_scope)
    offer = account.qualification_offers.enabled_in_order.find_by(id: conversation.offer_id)
    classification = AiLeadEmployee::ConversationIntentClassifier.new(
      message: followup.content,
      account: account,
      conversation: conversation,
      incoming_message: followup,
      offer: offer
    ).perform
    if conversation.additional_attributes.key?(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
      expect(classification.scope_clarification_consumed).to be(true)
    end
    expect(classification).to have_attributes(intent: :business_question, scope_question: expected_scope) if expected_scope
  end

  def question(key, prompt)
    { 'key' => key, 'meaning' => key.humanize, 'answer_type' => 'text', 'prompt' => prompt, 'position' => 0,
      'enabled' => true, 'required' => true, 'purpose' => 'fit' }
  end

  def create_offer(name: 'Growth coaching', qualification_mode: 'disabled', questions: [], next_step: { 'kind' => 'answer_only' })
    AiLeadEmployee::Offer.create!(
      account: account, name: name, currency: 'USD', enabled: true,
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
