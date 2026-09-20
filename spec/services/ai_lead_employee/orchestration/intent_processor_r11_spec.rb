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
                     message_type: :incoming, content: message, source_id: 'wamid.R11', provider_created_at: Time.current)
  end
  let(:intent) do
    create(:ai_orchestration_intent, account: account, conversation: conversation,
                                     triggering_message: triggering_message, observed_control_version: 2)
  end
  let(:message) { 'Do you integrate with Acme CRM?' }

  before do
    create(:ai_subscription, account: account, period_started_at: Time.current.beginning_of_day,
                             renews_at: 1.month.from_now.beginning_of_day, renewal_anchor_day: Time.current.day)
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

  it 'carries exact Pilot Authorization identity on a provider-free Review Acknowledgment' do
    offer = create_offer(qualification_mode: 'enabled', questions: [question('business_type', 'What business do you run?')])
    conversation.update!(offer: offer)
    provider = create(:ai_provider_connection, account: account)
    authorization = AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: conversation.control_version, provider_configuration_version: provider.configuration_version,
      max_attempts: 1, max_spend_usd: 1, provider_limit_usd: 1,
      external_owner_approval_reference: 'test-owner-approval', provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
                                 verification_digest: 'sha256:response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
    intent.update!(pilot_authorization: authorization)

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    _followup, confirmation_intent = followup_records(offer.name)
    confirmation_intent.update!(pilot_authorization: authorization)
    described_class.new(intent: confirmation_intent, enqueue_deliveries: false).perform

    expect(confirmation_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'no_approved_knowledge')
    authority = confirmation_intent.outbound_message.additional_attributes.fetch('ai_lead_employee')
    expect(authority).to include('pilot_authorization_id' => authorization.id,
                                 'outbound_intent_status' => 'review_acknowledgment')
    expect(authority).not_to include('provider_usage_id', 'provider_configuration_version', 'ai_reply_usage_id')
    expect(AiLeadEmployee::AiProviderUsage.where(pilot_authorization: authorization)).to be_empty
    expect(AiLeadEmployee::AiReplyUsage.where(ai_orchestration_intent: confirmation_intent)).to be_empty
  end

  it 'sets a polite boundary for an unrelated request without creating Review or qualification evidence' do
    triggering_message.update!(content: 'Who won the football match?')
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('I can help with questions about this business and its Offers.')
    expect(LeadQualification.where(contact: contact)).to be_empty
  end

  it 'carries exact Pilot Authorization identity on a provider-free Conversation Reply without usage or credit' do
    triggering_message.update!(content: 'Who won the football match?')
    provider = create(:ai_provider_connection, account: account)
    authorization = AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: conversation.control_version, provider_configuration_version: provider.configuration_version,
      max_attempts: 1, max_spend_usd: 1, provider_limit_usd: 1,
      external_owner_approval_reference: 'test-owner-approval', provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
                                 verification_digest: 'sha256:response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
    intent.update!(pilot_authorization: authorization)
    conversation.reload

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    authority = intent.reload.outbound_message.additional_attributes.fetch('ai_lead_employee')
    expect(authority).to include('pilot_authorization_id' => authorization.id,
                                 'outbound_intent_status' => 'conversation_reply')
    expect(authority).not_to include('provider_usage_id', 'provider_configuration_version', 'ai_reply_usage_id')
    expect(AiLeadEmployee::AiProviderUsage.where(pilot_authorization: authorization)).to be_empty
    expect(AiLeadEmployee::AiReplyUsage.where(ai_orchestration_intent: intent)).to be_empty
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
    usage = intent.ai_reply_usage.reload
    expect(intent.outbound_message.additional_attributes.dig('ai_lead_employee', 'ai_reply_usage_id')).to eq(usage.id)
    expect(intent.outbound_message.whatsapp_outbound_delivery.ai_reply_usage_id).to eq(usage.id)
    expect(usage).to have_attributes(status: 'reserved', expected_delivery_parts: 1)
    expect(usage.deliveries_registered_at).to be_present
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

  it 'preserves a conjunction-bearing configured name after a delimiter-free acknowledgment' do
    conversation.update!(offer: create_offer(name: 'Growth na Wellness'))
    triggering_message.update!(content: 'Je, mnakubali benki?')

    described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
    expect_scope_clarification!
    followup, followup_intent = followup_records('Ndiyo Growth na Wellness inajumuisha nini')
    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(followup_intent.reload).to be_blocked
    expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
    expect(followup_intent.decision.fetch('scope_resolution')).to include(
      'question' => 'Growth na Wellness inajumuisha nini', 'message_id' => followup.id, 'language' => 'swahili'
    )
  end

  ['Growth na Wellness inajumuisha nini', 'Growth na Wellness inajumuisha nini?',
   'Hapana, Growth na Wellness inajumuisha nini?'].each do |content|
    it "preserves a bare conjunction-bearing configured name while clarification is pending: #{content}" do
      conversation.update!(offer: create_offer(name: 'Growth na Wellness'))
      triggering_message.update!(content: 'Je, mnakubali benki?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      followup, followup_intent = followup_records(content)
      described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(followup_intent.reload).to be_blocked
      expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
      expect(followup_intent.decision.fetch('scope_resolution')).to include(
        'question' => 'Growth na Wellness inajumuisha nini', 'message_id' => followup.id, 'language' => 'swahili'
      )
    end
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
    'Will Growth Plan include coaching' => 'Growth Plan',
    'May Growth Academy offer installments' => 'Growth Academy',
    'Does Complete Online Business Growth Academy include coaching' => 'Complete Online Business Growth Academy'
  }.each do |content, offer_name|
    it "accepts an exact configured subject beyond generic modal ambiguity: #{content}" do
      conversation.update!(offer: create_offer(name: offer_name))
      triggering_message.update!(content: content)

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(intent.reload).to be_blocked
      expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
    end
  end

  {
    'Kozi ya Jua Academy inaanza lini' => 'Jua Academy',
    'Huduma ya Sema inajumuisha nini' => 'Sema'
  }.each do |content, offer_name|
    it "accepts an exact configured Swahili name that resembles a reporting stem: #{content}" do
      conversation.update!(offer: create_offer(name: offer_name))
      triggering_message.update!(content: content)
      classification = AiLeadEmployee::ConversationIntentClassifier.new(
        message: content, account: account, conversation: conversation, incoming_message: triggering_message,
        offer: conversation.offer
      ).perform

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(classification).to have_attributes(intent: :business_question, language: :swahili)
      expect(intent.reload).to be_blocked
      expect(intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
    end
  end

  it 'keeps a Swahili reporting verb outside the configured-name span declarative' do
    conversation.update!(offer: create_offer(name: 'Jua Academy'))
    triggering_message.update!(content: 'Asha alisema Jua Academy inaanza lini')
    classification = AiLeadEmployee::ConversationIntentClassifier.new(
      message: triggering_message.content, account: account, conversation: conversation,
      incoming_message: triggering_message, offer: conversation.offer
    ).perform

    expect(classification.intent).to eq(:generic_safe)
  end

  {
    'Tell me a football score na Growth na Wellness inajumuisha nini' =>
      ['Growth na Wellness', 'Growth na Wellness inajumuisha nini'],
    'What is the weather and does Growth and Wellness include coaching?' =>
      ['Growth and Wellness', 'does Growth and Wellness include coaching'],
    'Growth na Wellness then Growth na Wellness inajumuisha nini' =>
      ['Growth na Wellness', 'Growth na Wellness inajumuisha nini'],
    'Growth na Wellness inajumuisha nini na Growth na Wellness inaanza lini' =>
      ['Growth na Wellness', 'Growth na Wellness inaanza lini']
  }.each do |content, (offer_name, expected_question)|
    it "isolates a configured request after an unrelated clause: #{content}" do
      conversation.update!(offer: create_offer(name: offer_name))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      followup, followup_intent = followup_records(content)
      described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

      expect(followup_intent.reload).to be_blocked
      expect(followup_intent.review_request).to have_attributes(lead_message_id: followup.id)
      expect(followup_intent.decision.fetch('scope_resolution')).to include(
        'question' => expected_question, 'message_id' => followup.id
      )
    end
  end

  ['Yes, what does Pulse include and what does Netflix cost?',
   'What does Growth and Wellness include, and what does Netflix cost?',
   'Yes, what does Pulse include and what does Netflix cost and what does Pulse cover?'].each do |content|
    it "isolates a later external request after a configured request: #{content}" do
      offer_name = content.include?('Growth and Wellness') ? 'Growth and Wellness' : 'Pulse'
      conversation.update!(offer: create_offer(name: offer_name))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      followup_intent = process_followup(content)

      expect(followup_intent.reload).to have_attributes(state: 'completed', review_request: nil)
      expect(followup_intent.outbound_message.content).to eq(
        'I can help with questions about this business and its Offers.'
      )
    end
  end

  {
    'Yes what does Pulse include?' => 'Pulse',
    'Yes, and does Pulse include coaching' => 'Pulse',
    'Yes, and does Growth Plan include coaching' => 'Growth Plan',
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

  ['Maybe. I mean Pulse.', 'I was not sure; now I mean Pulse', "Maybe\nI mean Pulse", "Sijui\nNamaanisha Pulse",
   'Maybe—I mean Pulse', 'Sijui–Namaanisha Pulse', 'Maybe - I mean Pulse'].each do |content|
    it "uses a configured correction after a sentence or corrective boundary: #{content}" do
      conversation.update!(offer: create_offer(name: 'Pulse'))
      triggering_message.update!(content: 'Can I book a flight?')

      described_class.new(intent: intent, enqueue_deliveries: false, enforce_launch_gate: false).perform
      expect_scope_clarification!
      correction_intent = process_followup(content, expected_scope: triggering_message.content)

      expect(correction_intent.reload).to be_blocked
      expect(correction_intent.review_request).to have_attributes(lead_message_id: triggering_message.id)
    end
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

  ['Yes, actually no', 'Yes, actually no thanks', 'Yes, actually no thank you', 'Yes. Actually no. Thank you.',
   'Yes. Actually no. Thank you very much.', 'I mean Pulse, but no', 'Ndiyo, lakini hapana',
   'Ndiyo, lakini hapana asante', 'Ndiyo. Hapana. Asante.', 'Ndiyo. Hapana. Asante sana.',
   'Sijui. Hapana.'].each do |content|
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

  ['No, actually yes', 'No, actually yes please', 'No, actually yes thank you', 'Hapana, lakini ndiyo',
   'Hapana, lakini ndiyo tafadhali', 'Maybe. Yes.', 'Maybe. Yes. Thank you.',
   'Maybe. Yes. Thank you very much.', 'Sijui. Ndiyo. Asante.', 'Sijui. Ndiyo. Asante sana.'].each do |content|
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

  it 'does not bind a numeric reply when the prior question was omitted' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [question('team_size', 'How many team members do you have?').merge('answer_type' => 'number')]
    )
    conversation.update!(offer: offer)
    create(:message, account: account, inbox: channel.inbox, conversation: conversation,
                     message_type: :outgoing, content: 'Asante kwa maelezo.',
                     additional_attributes: {
                       'ai_lead_employee' => { 'qualification' => {
                         'offer_id' => offer.id, 'configuration_version' => offer.configuration_version,
                         'selection_version' => conversation.offer_selection_version,
                         'next_question_key' => 'team_size', 'next_question' => nil
                       } }
                     })
    triggering_message.update!(content: '12')

    evidence = AiLeadEmployee::OfferEvidenceRecorder.new(
      conversation: conversation, offer: offer, incoming_message: triggering_message
    ).perform

    expect(evidence).to be_empty
    expect(QualificationEvidence.where(offer: offer, field_key: 'team_size')).not_to exist
  end

  it 'binds a lead reply to the localized prompt that was actually emitted' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('team_size', 'How many team members do you have?').merge('answer_type' => 'number')
      ]
    )
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Wateja wangu ni wa hapa. Tafadhali nijibu kwa Kiswahili.')
    connection = create(:ai_provider_connection, account: account)
    intent.update!(pilot_authorization: create_pilot_authorization(connection))
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-localized-first-prompt', model: connection.model,
        content: {
          reply: 'Asante kwa maelezo.',
          observations: [
            { key: 'business_status', quote: 'Wateja wangu ni wa hapa.',
              typed_value: 'running', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: { team_size: 'Una wafanyakazi wangapi?' }
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )
    described_class.new(intent: intent, enqueue_deliveries: false).perform
    followup, followup_intent = followup_records('12')

    described_class.new(intent: followup_intent, enqueue_deliveries: false, enforce_launch_gate: false).perform

    expect(intent.outbound_message.content).to eq("Asante kwa maelezo.\n\nUna wafanyakazi wangapi?")
    expect(followup.reload).to be_incoming
    evidence = QualificationEvidence.find_by!(account: account, contact: contact, offer: offer, field_key: 'team_size')
    expect(evidence.value).to include('typed_value' => 12, 'polarity' => 'positive')
    expect(followup_intent.reload).to have_attributes(state: 'completed', review_request: nil)
  end

  it 'uses an English selected Offer document for a Swahili suitability question with one provider attempt' do
    offer = create_offer(name: 'Online Profits', qualification_mode: 'enabled')
    conversation.update!(offer: offer)
    triggering_message.update!(
      content: 'Nina biashara ya kufundisha watu mtandaoni. Je, programu yenu inaweza kunisaidia? Tafadhali nijibu kwa Kiswahili.'
    )
    document = create(
      :knowledge_document,
      account: account,
      title: 'Online Profits programme',
      body: 'Online Profits helps founders build marketing systems and improve follow-up.',
      general_question_access: false,
      offer_ids: [offer.id]
    )
    connection = create(:ai_provider_connection, account: account)
    intent.update!(pilot_authorization: create_pilot_authorization(connection))
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-cross-language-offer-doc', model: connection.model,
        content: 'Ndiyo, inaweza kusaidia kwa mifumo ya masoko na ufuatiliaji.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('Ndiyo, inaweza kusaidia kwa mifumo ya masoko na ufuatiliaji.')
    expect(intent.source_references).to contain_exactly(include('id' => document.id, 'type' => 'knowledge_document'))
    expect(provider_client).to have_received(:complete).once
  end

  it 'does not spend a provider attempt on an unknown selected Offer detail without lexical support' do
    offer = create_offer(name: 'Online Profits', qualification_mode: 'enabled')
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'For this programme, do you include weekend delivery?')
    create(
      :knowledge_document,
      account: account,
      title: 'Online Profits programme',
      body: 'Online Profits helps founders build marketing systems and improve follow-up.',
      general_question_access: false,
      offer_ids: [offer.id]
    )
    intent.update!(pilot_authorization: create_pilot_authorization(create(:ai_provider_connection, account: account)))

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload.source_references).to be_empty
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to have_received(:for)
  end

  it 'answers a mixed Swahili business question while recording only supported configured facts' do # rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations
    offer = create_offer(
      name: 'Mafunzo ya Biashara',
      currency: 'TZS',
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('monthly_business_revenue_tzs', 'What is your current monthly business revenue?').merge(
          'meaning' => 'Current monthly business revenue', 'answer_type' => 'money', 'period' => 'monthly'
        ),
        question('expert_willingness', 'Would you like to speak with an expert?').merge(
          'meaning' => 'Willingness to speak with an expert', 'answer_type' => 'boolean'
        )
      ],
      next_step: { 'kind' => 'sales_call', 'agreement_field' => 'sales_call_agreement' }
    )
    conversation.update!(offer: offer)
    triggering_message.update!(
      content: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni. ' \
               'Mapato yangu ni shilingi 800,000 kwa mwezi, na lengo ni kufikia milioni 3. ' \
               'Je, programu yenu inaweza kunisaidia? Tafadhali nijibu kwa Kiswahili.'
    )
    document = create(
      :knowledge_document,
      account: account,
      title: 'Business training programme',
      body: 'This programme can help online training businesses improve marketing systems and follow-up.',
      general_question_access: false,
      offer_ids: [offer.id]
    )
    connection = create(:ai_provider_connection, account: account)
    intent.update!(pilot_authorization: create_pilot_authorization(connection))
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-mixed-swahili', model: connection.model,
        content: {
          reply: 'Programu hii inaweza kusaidia biashara za mafunzo mtandaoni.',
          observations: [
            { key: 'business_status', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
              typed_value: 'running', asserted: true, certainty: 'certain' },
            { key: 'monthly_business_revenue_tzs', quote: 'Mapato yangu ni shilingi 800,000 kwa mwezi',
              typed_value: 80_000_000, asserted: true, certainty: 'certain' },
            { key: 'monthly_business_revenue_tzs', quote: 'lengo ni kufikia milioni 3',
              typed_value: 300_000_000, asserted: true, certainty: 'certain' },
            { key: 'expert_willingness', quote: 'Je, programu yenu inaweza kunisaidia?',
              typed_value: true, asserted: true, certainty: 'certain' }
          ],
          localized_prompts: { expert_willingness: 'Je, ungependa kuzungumza na mtaalamu?' }
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq(
      "Programu hii inaweza kusaidia biashara za mafunzo mtandaoni.\n\nJe, ungependa kuzungumza na mtaalamu?"
    )
    expect(intent.source_references).to contain_exactly(include('id' => document.id, 'type' => 'knowledge_document'))
    expect(provider_client).to have_received(:complete).once
    evidence = QualificationEvidence.where(account: account, contact: contact, offer: offer).index_by(&:field_key)
    expect(evidence).to include('business_status', 'monthly_business_revenue_tzs')
    expect(evidence['business_status'].value).to include('typed_value' => 'running')
    expect(evidence['monthly_business_revenue_tzs'].value).to include('typed_value' => 80_000_000, 'currency' => 'TZS')
    expect(evidence).not_to include('expert_willingness', 'sales_call_agreement')
  end

  it 'uses managed billing to extract configured facts from an ordinary mixed business question' do
    offer = create_offer(
      name: 'Mafunzo ya Biashara',
      currency: 'TZS',
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('monthly_business_revenue_tzs', 'What is your current monthly business revenue?').merge(
          'meaning' => 'Current monthly business revenue', 'answer_type' => 'money', 'period' => 'monthly'
        )
      ]
    )
    conversation.update!(offer: offer)
    triggering_message.update!(
      content: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni. ' \
               'Mapato yangu ni shilingi 800,000 kwa mwezi. Je, programu yenu inaweza kunisaidia?'
    )
    create(
      :knowledge_item,
      account: account,
      question: triggering_message.content,
      answer: 'Programu hii inaweza kusaidia biashara za mafunzo mtandaoni.',
      metadata: { 'source_reference' => 'ordinary-swahili-business-fit-v1', 'offer_ids' => [offer.id], 'language' => 'swahili' }
    )
    connection = create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-ordinary-mixed-swahili', model: connection.model,
        content: {
          reply: 'Programu hii inaweza kusaidia biashara za mafunzo mtandaoni.',
          observations: [
            { key: 'business_status', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
              typed_value: 'running', asserted: true, certainty: 'certain' },
            { key: 'monthly_business_revenue_tzs', quote: 'Mapato yangu ni shilingi 800,000 kwa mwezi',
              typed_value: 80_000_000, asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(provider_client).to have_received(:complete).once
    expect(intent.ai_reply_usage).to be_reserved
    evidence = QualificationEvidence.where(account: account, contact: contact, offer: offer).index_by(&:field_key)
    expect(evidence['business_status'].value).to include('typed_value' => 'running')
    expect(evidence['monthly_business_revenue_tzs'].value).to include('typed_value' => 80_000_000, 'currency' => 'TZS')
  end

  it 'uses one provider attempt when legacy business_type evidence does not cover configured fields' do
    offer = create_offer(
      currency: 'TZS',
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('monthly_business_revenue_tzs', 'What is your current monthly business revenue?').merge(
          'meaning' => 'Current monthly business revenue', 'answer_type' => 'money', 'period' => 'monthly'
        )
      ]
    )
    conversation.update!(offer: offer)
    create_prompted_question_message(offer, key: 'business_status', prompt: 'Do you currently run a business?')
    triggering_message.update!(content: 'My business is local. We make TZS 900,000 per month.')
    connection = create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-legacy-business-type-gap', model: connection.model,
        content: {
          reply: 'Thanks for those details.',
          observations: [
            { key: 'business_status', quote: 'My business is local.',
              typed_value: 'running', asserted: true, certainty: 'certain' },
            { key: 'monthly_business_revenue_tzs', quote: 'We make TZS 900,000 per month',
              typed_value: 90_000_000, asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(provider_client).to have_received(:complete).once
    evidence = QualificationEvidence.where(account: account, contact: contact, offer: offer).index_by(&:field_key)
    expect(evidence).to include('business_type', 'business_status', 'monthly_business_revenue_tzs')
    expect(evidence['business_status'].value).to include('typed_value' => 'running')
    expect(evidence['monthly_business_revenue_tzs'].value).to include('typed_value' => 90_000_000)
  end

  it 'uses one provider attempt when unrelated legacy problem evidence does not cover a pending custom field' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('customer_segment', 'Which customer segment do you serve?').merge(
          'meaning' => 'Current customer segment', 'answer_type' => 'choice', 'options' => %w[local export]
        )
      ]
    )
    conversation.update!(offer: offer)
    create_prompted_question_message(offer, key: 'customer_segment', prompt: 'Which customer segment do you serve?')
    triggering_message.update!(content: 'I need help because my customers are local.')
    connection = create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-legacy-problem-custom-gap', model: connection.model,
        content: {
          reply: 'Thanks for those details.',
          observations: [
            { key: 'customer_segment', quote: 'my customers are local',
              typed_value: 'local', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(provider_client).to have_received(:complete).once
    evidence = QualificationEvidence.where(account: account, contact: contact, offer: offer).index_by(&:field_key)
    expect(evidence).to include('problem', 'customer_segment')
    expect(evidence['customer_segment'].value).to include('typed_value' => 'local')
  end

  it 'uses one pilot provider attempt to interpret pure free-text qualification when local parsing has no evidence' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('team_size', 'How many team members do you have?').merge('answer_type' => 'number')
      ]
    )
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'My customers are mostly local.')
    connection = create(:ai_provider_connection, account: account)
    intent.update!(pilot_authorization: create_pilot_authorization(connection))
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-pure-qualification', model: connection.model,
        content: {
          reply: 'Thanks for those details.',
          observations: [
            { key: 'business_status', quote: 'My customers are mostly local.',
              typed_value: 'running', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq("Thanks for those details.\n\nHow many team members do you have?")
    expect(provider_client).to have_received(:complete).once
    evidence = QualificationEvidence.find_by!(account: account, contact: contact, offer: offer, field_key: 'business_status')
    expect(evidence.value).to include('typed_value' => 'running')
    authority = intent.outbound_message.additional_attributes.fetch('ai_lead_employee')
    expect(authority).to include('provider_configuration_version' => connection.configuration_version)
  end

  it 'omits the next Swahili qualification question when the provider does not translate the owner prompt' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('team_size', 'How many team members do you have?').merge('answer_type' => 'number')
      ]
    )
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'Wateja wangu ni wa hapa. Tafadhali nijibu kwa Kiswahili.')
    connection = create(:ai_provider_connection, account: account)
    intent.update!(pilot_authorization: create_pilot_authorization(connection))
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-swahili-no-prompt', model: connection.model,
        content: {
          reply: 'Asante kwa maelezo.',
          observations: [
            { key: 'business_status', quote: 'Wateja wangu ni wa hapa.',
              typed_value: 'running', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(intent.outbound_message.content).to eq('Asante kwa maelezo.')
    expect(intent.outbound_message.content).not_to include('How many team members')
  end

  it 'uses the structured qualification path for ordinary enabled accounts with customer allowance controls' do # rubocop:disable RSpec/MultipleExpectations
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        ),
        question('team_size', 'How many team members do you have?').merge('answer_type' => 'number')
      ]
    )
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'My customers are mostly local.')
    connection = create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-nonpilot-qualification', model: connection.model,
        content: {
          reply: 'Thanks for those details.',
          observations: [
            { key: 'business_status', quote: 'My customers are mostly local.',
              typed_value: 'running', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'completed', review_request: nil)
    expect(provider_client).to have_received(:complete).once
    expect(provider_client).to have_received(:complete) do |arguments|
      prompt = arguments.fetch(:messages).last.fetch(:content)
      expect(prompt).to include('Do you currently run a business?', 'Current business status', 'USD', 'english', 'business_status')
    end
    expect(intent.ai_reply_usage).to be_reserved
    evidence = QualificationEvidence.find_by!(account: account, contact: contact, offer: offer, field_key: 'business_status')
    expect(evidence.value).to include('typed_value' => 'running')
    authority = intent.outbound_message.additional_attributes.fetch('ai_lead_employee')
    expect(authority).to include('provider_configuration_version' => connection.configuration_version,
                                 'ai_reply_usage_id' => intent.ai_reply_usage.id)
    expect(authority).not_to include('pilot_authorization_id')
  end

  it 'rejects structured observations when the selected Offer changes during the provider call' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        )
      ]
    )
    replacement = create_offer(name: 'Replacement', qualification_mode: 'enabled')
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'My customers are mostly local.')
    connection = create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(provider_client).to receive(:complete) do
      conversation.update!(offer: replacement)
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-offer-drift', model: connection.model,
        content: {
          reply: 'Thanks for those details.',
          observations: [
            { key: 'business_status', quote: 'My customers are mostly local.',
              typed_value: 'running', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    end

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
    expect(QualificationEvidence.where(account: account, contact: contact, offer: offer, field_key: 'business_status')).to be_empty
  end

  it 'rejects structured observations when the selected Offer configuration changes during the provider call' do
    offer = create_offer(
      qualification_mode: 'enabled',
      questions: [
        question('business_status', 'Do you currently run a business?').merge(
          'meaning' => 'Current business status', 'answer_type' => 'choice', 'options' => %w[running not_running]
        )
      ]
    )
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'My customers are mostly local.')
    connection = create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(provider_client).to receive(:complete) do
      offer.update!(configuration_version: offer.configuration_version + 1)
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-offer-config-drift', model: connection.model,
        content: {
          reply: 'Thanks for those details.',
          observations: [
            { key: 'business_status', quote: 'My customers are mostly local.',
              typed_value: 'running', asserted: true, certainty: 'certain' }
          ],
          localized_prompts: {}
        }.to_json,
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    end

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
    expect(QualificationEvidence.where(account: account, contact: contact, offer: offer, field_key: 'business_status')).to be_empty
  end

  it 'blocks malformed pilot structured output without sending the raw provider payload' do
    offer = create_offer(qualification_mode: 'enabled', questions: [
                           question('business_status', 'Do you currently run a business?').merge(
                             'answer_type' => 'choice', 'options' => %w[running not_running]
                           )
                         ])
    conversation.update!(offer: offer)
    triggering_message.update!(content: 'My customers are mostly local.')
    connection = create(:ai_provider_connection, account: account)
    intent.update!(pilot_authorization: create_pilot_authorization(connection))
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-malformed-qualification', model: connection.model, content: 'not json',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failed')
    expect(intent.outbound_message.content).to eq(
      'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.'
    )
    expect(intent.outbound_message.content).not_to include('not json')
    expect(QualificationEvidence.where(account: account, contact: contact, offer: offer, field_key: 'business_status')).to be_empty
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
    expect_nonbillable_review_delivery(confirmation_intent)
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
    expect_nonbillable_review_delivery(intent)
  end

  def expect_nonbillable_review_delivery(processed_intent)
    expect(processed_intent.ai_reply_usage.reload).to be_released
    acknowledgment = processed_intent.outbound_message
    expect(acknowledgment.additional_attributes.dig('ai_lead_employee', 'ai_reply_usage_id')).to be_nil
    expect(acknowledgment.whatsapp_outbound_delivery.ai_reply_usage_id).to be_nil
    expect(AiLeadEmployee::ReplyAllowance.delivery_failure_code(message: acknowledgment)).to be_nil
    expect_review_delivery_eligible(acknowledgment)
  end

  def expect_review_delivery_eligible(acknowledgment)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    expect(Whatsapp::OutboundEligibility.new(
      delivery: acknowledgment.whatsapp_outbound_delivery, channel: channel,
      recipient: contact_inbox.source_id, authority_records: {}
    ).failure_code).to be_nil
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

  def create_prompted_question_message(offer, key:, prompt:)
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content: "Thanks.\n\n#{prompt}",
      additional_attributes: {
        'ai_lead_employee' => {
          'qualification' => {
            'offer_id' => offer.id,
            'configuration_version' => offer.configuration_version,
            'selection_version' => conversation.offer_selection_version,
            'next_question' => prompt,
            'next_question_key' => key
          }
        }
      }
    )
  end

  def create_offer(name: 'Growth coaching', currency: 'USD', qualification_mode: 'disabled', questions: [],
                   next_step: { 'kind' => 'answer_only' })
    AiLeadEmployee::Offer.create!(
      account: account, name: name, currency: currency, enabled: true,
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

  def create_pilot_authorization(connection)
    AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: conversation,
      ai_provider_connection: connection, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: conversation.control_version, provider_configuration_version: connection.configuration_version,
      max_attempts: 3, max_spend_usd: 1, provider_limit_usd: 1,
      external_owner_approval_reference: 'test-owner-approval', provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
                                 verification_digest: 'sha256:response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
  end
end
