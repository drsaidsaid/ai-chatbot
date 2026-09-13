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
    'Do you offer certificates?' => [:english, 'okay'],
    'Do you allow rescheduling?' => [:english, 'Yes, that is what I mean'],
    'Do you provide recordings?' => [:english, 'Okay?'],
    'Do you provide support?' => [:english, 'No, I mean your business'],
    'Do you provide templates?' => [:english, 'Sure'],
    'Do you provide coaching?' => [:english, "That's right"],
    'Do you provide onboarding?' => [:english, 'Please do'],
    'Je, mnakubali M-Pesa?' => [:swahili, 'ndiyo'],
    'Mnasafirisha hadi Arusha?' => [:swahili, 'Ofa hii'],
    'Je, mnakubali Airtel Money?' => [:swahili, 'sawa'],
    'Je, mnasafirisha Jumapili?' => [:swahili, 'Ndiyo tafadhali'],
    'Je, mnakubali benki?' => [:swahili, 'Sawa?'],
    'Je, mnafundisha wikendi?' => [:swahili, 'Hapana, ni kuhusu biashara hii']
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

  it 'sets a boundary for an explicit unrelated category in statement form' do
    triggering_message.update!(content: 'Tell me a football score')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  it 'classifies named third-party questions consistently regardless of capitalization' do
    account.update!(name: 'France')
    conversation.update!(offer: create_offer(name: 'Capital'))
    triggering_message.update!(content: 'what is the capital of France?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  it 'consumes a denial without treating it as Business confirmation' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    denial_intent = process_followup('No, I am not asking about this business.')

    expect(denial_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(denial_intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    expect(conversation.reload.additional_attributes).not_to have_key(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
  end

  ['No, I do not mean your business.', 'Hapana, simaanishi biashara hii.', 'No, not Pulse.'].each do |denial|
    it "does not turn a scope-target denial into confirmation: #{denial}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      denial_intent = process_followup(denial)

      expect(denial_intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expected = if AiLeadEmployee::LanguageDetector.detect(denial) == :swahili
                   'Ninaweza kusaidia kwa maswali kuhusu biashara hii na Ofa zake.'
                 else
                   'I can help with questions about this business and its Offers.'
                 end
      expect(denial_intent.outbound_message.content).to eq(expected)
    end
  end

  it 'classifies a new question after a denial independently' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, followup_intent = followup_records('No, I am not asking about this business. What does Pulse include?')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to be_blocked
    expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
  end

  ['No, I am not asking about this business, but what does Pulse include?',
   "No, I am not asking about this business\nWhat does Pulse include?",
   'No, I am not asking about this business—what does Pulse include?',
   'No, not Netflix, tell me about Pulse',
   'Yes, and what does Pulse include?'].each do |content|
    it "classifies a compound replacement request independently: #{content}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      followup, followup_intent = followup_records(content)
      described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(followup_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
      expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
    end
  end

  it 'uses an extracted compound request for approved-knowledge retrieval' do
    conversation.update!(offer: create_offer(name: 'Growth and Wellness'))
    triggering_message.update!(content: 'Can I book a flight?')
    create(
      :knowledge_item,
      account: account,
      question: 'What does Growth and Wellness include?',
      answer: 'Growth and Wellness includes weekly coaching.'
    )
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r11-compound-answer', model: connection.model, content: 'Growth and Wellness includes weekly coaching.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, followup_intent = followup_records('Yes, and what does Growth and Wellness include?')
    expect_followup_classification!(followup, 'what does Growth and Wellness include')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(followup_intent.outbound_message.content).to eq('Growth and Wellness includes weekly coaching.')
    expect(followup_intent.decision.dig('scope_resolution', 'message_id')).to eq(followup.id)
  end

  it 'preserves the complete configured name when it contains a conjunction' do
    conversation.update!(offer: create_offer(name: 'Health and Wellness'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, = followup_records('Yes, and what does Health and Wellness include?')

    expect_followup_classification!(followup, 'what does Health and Wellness include')
  end

  it 'sets the boundary from an extracted compound third-party request' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup_intent = process_followup('Yes, and what does Netflix cost?')

    expect(followup_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(followup_intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  it 'preserves extracted question provenance when its provider request fails' do
    offer = create_offer(name: 'Pulse')
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Can I book a flight?')
    create(
      :knowledge_item,
      account: account,
      question: 'What does Pulse include?',
      answer: 'Pulse includes weekly coaching.',
      metadata: { 'source_reference' => 'pulse-compound-failure-v1', 'offer_ids' => [offer.id], 'language' => 'english' }
    )
    create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_raise(AiLeadEmployee::AiProvider::TimeoutFailure)

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, followup_intent = followup_records('Yes, and what does Pulse include?')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failure')
    expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
    expect(followup_intent.decision.fetch('scope_resolution')).to include(
      'question' => 'what does Pulse include', 'message_id' => followup.id, 'language' => 'english'
    )
  end

  it 'classifies a terminal Swahili question after confirmation as a new request' do
    conversation.update!(offer: create_offer(name: 'Growth Academy'))
    triggering_message.update!(content: 'Je, mnakubali benki?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, followup_intent = followup_records('Ndiyo, na Growth Academy inajumuisha nini')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to be_blocked
    expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
  end

  it 'retrieves Swahili-only knowledge for an extracted gani question' do
    offer = create_offer(name: 'Pulse')
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Je, mnakubali benki?')
    create(
      :knowledge_item,
      account: account,
      question: 'Kozi inaanza siku gani',
      answer: 'Kozi inaanza Jumatatu.',
      metadata: { 'source_reference' => 'pulse-swahili-start-v1', 'offer_ids' => [offer.id], 'language' => 'swahili' }
    )
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r11-swahili-answer', model: connection.model, content: 'Kozi inaanza Jumatatu.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, followup_intent = followup_records('Ndiyo, na Kozi inaanza siku gani')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(followup_intent.outbound_message.content).to eq('Kozi inaanza Jumatatu.')
    expect(followup_intent.decision.fetch('scope_resolution')).to include(
      'question' => 'Kozi inaanza siku gani', 'message_id' => followup.id, 'language' => 'swahili'
    )
  end

  {
    'Yes what does Pulse include?' => 'Pulse',
    'Yes, and does Pulse include coaching' => 'Pulse',
    'Ndiyo Pulse inajumuisha nini' => 'Pulse',
    'Ndiyo Bei ya Pulse ni nini' => 'Pulse',
    'Ndiyo, na Online Profits inajumuisha nini' => 'Online Profits'
  }.each do |content, offer_name|
    it "extracts an acknowledgment followed by a request: #{content}" do
      conversation.update!(offer: create_offer(name: offer_name))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      followup, followup_intent = followup_records(content)
      described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(followup_intent.reload).to be_blocked
      expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
    end
  end

  it 'uses a later configured correction after rejecting the broad Business scope' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    correction_intent = process_followup('I do not mean your business; I mean Pulse', expected_scope: triggering_message.content)

    expect(correction_intent.reload).to be_blocked
    expect(correction_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
  end

  it 'uses a later configured correction after an earlier uncertainty' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    correction_intent = process_followup('I was not sure, but I mean Pulse', expected_scope: triggering_message.content)

    expect(correction_intent.reload).to be_blocked
    expect(correction_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
  end

  it 'accepts a configured correction with a determiner and scope noun' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    correction_intent = process_followup('I do not mean your business; I mean the Pulse offer', expected_scope: triggering_message.content)

    expect(correction_intent.reload).to be_blocked
    expect(correction_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
  end

  it 'uses the last explicit scoped proposition when a later clause denies the configured Offer' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    denial_intent = process_followup('I mean Pulse, but actually not about Pulse')

    expect(denial_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(denial_intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  ['Yes, actually no', 'Yes, actually no thanks', 'I mean Pulse, but no', 'Ndiyo, lakini hapana',
   'Ndiyo, lakini hapana asante'].each do |content|
    it "uses a trailing bare denial as the last scoped proposition: #{content}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      denial_intent = process_followup(content)

      expect(denial_intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expected_boundary = if AiLeadEmployee::LanguageDetector.detect(content) == :swahili
                            'Ninaweza kusaidia kwa maswali kuhusu biashara hii na Ofa zake.'
                          else
                            'I can help with questions about this business and its Offers.'
                          end
      expect(denial_intent.outbound_message.content).to eq(expected_boundary)
    end
  end

  ['No, actually yes', 'No, actually yes please', 'Hapana, lakini ndiyo', 'Hapana, lakini ndiyo tafadhali'].each do |content|
    it "uses a trailing bare confirmation as the last scoped proposition: #{content}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      confirmation_intent = process_followup(content, expected_scope: triggering_message.content)

      expect(confirmation_intent.reload).to be_blocked
      expect(confirmation_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
    end
  end

  it 'evaluates a new unrelated request independently while clarification is pending' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup_intent = process_followup('Tell me a football score')

    expect(followup_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(followup_intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  ['I am not sure', "I'm not sure"].each do |content|
    it "repeats the original clarification for an uncertain acknowledgment: #{content}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      uncertain_intent = process_followup(content)

      expect(uncertain_intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(uncertain_intent.outbound_message.content).to eq('Are you asking about this business or one of its Offers?')
      context = conversation.reload.additional_attributes.fetch(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
      expect(context).to include('question' => triggering_message.content, 'message_id' => triggering_message.id)
    end
  end

  ['Maybe, your business', 'Labda, biashara hii', "Yes, I'm not sure", 'Okay, maybe', 'Sawa, sijui',
   'Maybe I mean Pulse', "I'm not sure I mean Pulse", 'Maybe not about Pulse', 'Sijui, si kuhusu Pulse'].each do |content|
    it "re-clarifies an uncertain scope-tail acknowledgment: #{content}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      uncertain_intent = process_followup(content)

      expect(uncertain_intent.reload).to have_attributes(state: 'completed', review_request: nil)
      context = conversation.reload.additional_attributes.fetch(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
      expect(context).to include('question' => triggering_message.content, 'message_id' => triggering_message.id)
    end
  end

  it 'classifies a substantive next question independently instead of using it as confirmation' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    followup, followup_intent = followup_records('What does Pulse include?')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
  end

  it 'classifies a declarative information request independently instead of using it as confirmation' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    followup, followup_intent = followup_records('Tell me about Pulse')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to be_blocked
    expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
  end

  it 'treats a named correction containing negation as confirmation of the selected Offer' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    confirmation_intent = process_followup('No—not Netflix, Pulse', expected_scope: triggering_message.content)

    expect(confirmation_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(confirmation_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
  end

  it 'rejects pending scope when another public prompt intervenes' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'Can I book a flight?')
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content: 'A newer public prompt.'
    )

    confirmation_intent = process_followup('yes')

    expect(confirmation_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(confirmation_intent.outbound_message.content).to eq('Could you tell me what you need about this business?')
    expect(conversation.reload.additional_attributes).not_to have_key(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
  end

  it 're-clarifies the original question when its selected Offer changes before confirmation' do
    original_offer = create_offer(name: 'Pulse')
    conversation.update!(offer: original_offer)
    triggering_message.update!(content: 'Are there weekend classes?')
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    original_context = conversation.reload.additional_attributes.fetch(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
    expect(original_context).to include(
      'offer_id' => original_offer.id,
      'offer_configuration_version' => original_offer.configuration_version
    )

    replacement_offer = create_offer(name: 'Focus')
    conversation.update!(offer: replacement_offer)
    first_followup, first_confirmation = followup_records('yes')
    drifted_classification = AiLeadEmployee::ConversationIntentClassifier.new(
      message: first_followup.content,
      account: account,
      conversation: conversation,
      incoming_message: first_followup,
      offer: replacement_offer
    ).perform
    expect(drifted_classification.intent).to eq(:scope_clarification)
    described_class.new(intent: first_confirmation, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(first_confirmation.reload.outbound_message.content).to eq('Are you asking about this business or one of its Offers?')
    context = conversation.reload.additional_attributes.fetch(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
    expect(context).to include(
      'question' => triggering_message.content,
      'message_id' => triggering_message.id,
      'offer_id' => replacement_offer.id,
      'offer_configuration_version' => replacement_offer.configuration_version
    )

    second_confirmation = process_followup('yes', expected_scope: triggering_message.content)
    expect(second_confirmation.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    expect(second_confirmation.review_request).to have_attributes(lead_message_id: triggering_message.id)
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

  it 'prefers an exact configured Offer name over a third-party commerce heuristic' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'How much does Pulse cost?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to be_blocked
    expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
  end

  it 'keeps a configured Offer relevant in an external-fact sentence shape' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'What is the price of Pulse?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to be_blocked
    expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
  end

  ['Who is the instructor of Pulse?', 'What is the refund policy of Pulse?'].each do |question|
    it "keeps the selected Offer authoritative for: #{question}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: question)

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to be_blocked
      expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
    end
  end

  ['Who is the instructor of Netflix?', 'What is the refund policy of Netflix?', 'What is the price of Netflix?'].each do |question|
    it "sets a boundary for an unconfigured external subject: #{question}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: question)
      conversation.reload

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    end
  end

  it 'does not let a collision-prone configured name override an unrelated category' do
    conversation.update!(offer: create_offer(name: 'Weather'))
    triggering_message.update!(content: 'What is the weather?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  ['Football Academy', 'Pilau Catering'].each do |name|
    it "keeps a specific configured name authoritative despite a category token: #{name}" do
      conversation.update!(offer: create_offer(name: name))
      triggering_message.update!(content: "What does #{name} include?")

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to be_blocked
      expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
    end
  end

  it 'does not let a configured Offer name override an unrelated physiological question' do
    conversation.update!(offer: create_offer(name: 'Pulse'))
    triggering_message.update!(content: 'What is my pulse?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
  end

  it 'prefers addressed Account-name context over a fixed unrelated category' do
    account.update!(name: 'Pilau Catering')
    triggering_message.update!(content: 'What is your pilau price?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to be_blocked
    expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
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

  it 'preserves the clarified question across lease recovery' do
    offer = create_offer(name: 'Pulse')
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Are there weekend classes?')
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    create(
      :knowledge_item,
      account: account,
      question: triggering_message.content,
      answer: 'Pulse has weekend classes.',
      metadata: { 'source_reference' => 'pulse-weekend-recovery-v1', 'offer_ids' => [offer.id], 'language' => 'english' }
    )
    connection = create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r11-recovered-answer', model: connection.model, content: 'Pulse has weekend classes.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )
    _confirmation, confirmation_intent = followup_records('yes')

    first_attempt = described_class.new(intent: confirmation_intent, enqueue_deliveries: false, enforce_launch_gate: false)
    expect(first_attempt.send(:prepare_claimed_answer)).to be(true)
    expect(confirmation_intent.reload.decision.dig('scope_resolution', 'question')).to eq(triggering_message.content)
    expect(conversation.reload.additional_attributes).not_to have_key(AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY)
    confirmation_intent.update!(lease_expires_at: 1.minute.ago)

    described_class.new(intent: confirmation_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(confirmation_intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(confirmation_intent.outbound_message.content).to eq('Pulse has weekend classes.')
  end

  it 'links provider-failure Review to the original clarified question' do
    offer = create_offer(name: 'Pulse')
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Are there weekend classes?')
    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    create(
      :knowledge_item,
      account: account,
      question: triggering_message.content,
      answer: 'Pulse has weekend classes.',
      metadata: { 'source_reference' => 'pulse-weekend-failure-v1', 'offer_ids' => [offer.id], 'language' => 'english' }
    )
    create(:ai_provider_connection, account: account)
    allow(provider_client).to receive(:complete).and_raise(AiLeadEmployee::AiProvider::TimeoutFailure)

    confirmation_intent = process_followup('yes', expected_scope: triggering_message.content)

    expect(confirmation_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failure')
    expect(confirmation_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
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
    followup.reload
    [followup, followup_intent]
  end

  def expect_followup_classification!(followup, expected_scope)
    offer = account.qualification_offers.enabled_in_order.find_by(id: conversation.offer_id)
    context = conversation.additional_attributes[AiLeadEmployee::BusinessScopeRelevance::CONTEXT_KEY]
    expect_bound_clarification_prompt!(context, followup) if context && expected_scope
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

  def expect_bound_clarification_prompt!(context, followup)
    previous_public_id = Message.where(
      conversation_id: conversation.id,
      private: false,
      message_type: [Message.message_types[:incoming], Message.message_types[:outgoing]]
    ).where('messages.id < ?', followup.id).reorder(id: :desc).pick(:id)
    expect(context['clarification_message_id']).to eq(previous_public_id)
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
