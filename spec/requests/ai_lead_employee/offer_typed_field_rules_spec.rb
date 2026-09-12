# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Typed Offer answers and qualification rules', type: :request do
  include_context 'with Offer qualification requests'

  it 'binds a revenue amount to the actual outgoing question without converting it into budget or inquiry volume' do
    question = r09_question('monthly_revenue', answer_type: 'money', prompt: 'What is your monthly business revenue?', period: 'month')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    conversation = r09_conversation(offer: offer)
    _greeting, asked = r09_receive(conversation, 'Hello')
    expect(asked.outbound_message.additional_attributes.dig('ai_lead_employee', 'qualification')).to include(
      'offer_id' => offer.fetch('id'), 'next_question_key' => 'monthly_revenue', 'configuration_version' => offer.fetch('version')
    )

    answer, replied = r09_receive(conversation, 'TZS 1200000')
    snapshot = r09_qualification(offer).evidence_snapshot

    expect(snapshot.fetch('monthly_revenue')).to include(
      'polarity' => 'positive', 'amount_minor' => 120_000_000, 'currency' => 'TZS', 'period' => 'month', 'message_id' => answer.id
    )
    expect(snapshot.keys).not_to include('budget', 'lead_volume')
    expect(replied.outbound_message.content).not_to include(question.fetch('prompt'))
  end

  [
    ['team_size', 'number', 'How many people work in your team?', '12', 12, 'positive', {}],
    ['uses_crm', 'boolean', 'Do you currently use a CRM?', 'Hapana', false, 'negative', {}],
    ['customer_type', 'choice', 'Are your customers B2B or B2C?', 'B2B', 'B2B', 'positive', { options: %w[B2B B2C] }],
    ['support_topic', 'text', 'Which part of your operations needs support?', 'Remote onboarding', 'Remote onboarding', 'positive', {}]
  ].each do |scenario|
    key, type, prompt, answer, typed_value, polarity, options = scenario

    it "records a verified #{type} answer as a typed fact and does not ask it again" do
      question = r09_question(key, answer_type: type, prompt: prompt, **options)
      offer = r09_create_offer(r09_configuration(questions: [question]))
      conversation = r09_conversation(offer: offer)
      r09_receive(conversation, 'Hello')

      incoming, replied = r09_receive(conversation, answer)

      expect(r09_qualification(offer).evidence_snapshot.fetch(key)).to include(
        'typed_value' => typed_value, 'polarity' => polarity, 'message_id' => incoming.id
      )
      expect(replied.outbound_message.content).not_to include(prompt)
    end
  end

  it 'does not populate revenue from a different explicit budget fact in the answer' do
    question = r09_question('monthly_revenue', answer_type: 'money', prompt: 'What is your monthly business revenue?', period: 'month')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')

    incoming, replied = r09_receive(conversation, 'Correction: my budget is TZS 600000.')

    expect(r09_qualification(offer).evidence_snapshot.fetch('budget')).to include('message_id' => incoming.id)
    expect(r09_qualification(offer).evidence_snapshot).not_to have_key('monthly_revenue')
    expect(replied.outbound_message.content).to include(question.fetch('prompt'))
  end

  it 'does not borrow a custom question from another Conversation of the same Lead' do
    question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    asked_conversation = r09_conversation(offer: offer)
    other_conversation = r09_conversation(offer: offer)
    r09_receive(asked_conversation, 'Hello')

    r09_receive(other_conversation, '12')

    expect(r09_qualification(offer).evidence_snapshot).not_to have_key('team_size')
  end

  it 'records an unknown answer without scoring it or repeatedly asking the same question' do
    question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
    offer = r09_create_offer(r09_configuration(questions: [question], score_weights: { team_size: 50 }))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')

    incoming, replied = r09_receive(conversation, 'Sijui.')

    expect(r09_qualification(offer)).to have_attributes(score: 0, quality: 'unknown')
    expect(r09_qualification(offer).missing_signals).to include('team_size')
    expect(r09_qualification(offer).evidence_snapshot.fetch('team_size')).to include('polarity' => 'unknown', 'message_id' => incoming.id)
    expect(replied.outbound_message.content).not_to include(question.fetch('prompt'))
  end

  it 'applies a saved numeric score rule with its reason while keeping unsupported budget as missing evidence' do
    question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
    rule = { kind: 'score_rule', field: 'team_size', operator: 'gte', value: 10, score_delta: 30, priority: 0, enabled: true }
    offer = r09_create_offer(r09_configuration(questions: [question], rules: [rule], score_weights: { team_size: 0 }))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')

    answer, = r09_receive(conversation, '12')
    qualification = r09_qualification(offer)

    expect(qualification).to have_attributes(score: 30, quality: 'low_qualified')
    expect(qualification.reasons.join(' ').downcase).to include('team size', '30')
    expect(qualification.missing_signals).to include('budget')
    expect(qualification.evidence_snapshot.fetch('team_size')).to include('message_id' => answer.id)
  end

  it 'lets a typed hard exclusion override a high score' do
    question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
    rule = { kind: 'hard_rule', field: 'team_size', operator: 'lt', value: 5, forced_outcome: 'unqualified', priority: 0, enabled: true }
    offer = r09_create_offer(r09_configuration(questions: [question], rules: [rule], score_weights: { team_size: 100 }))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')

    r09_receive(conversation, '3')

    expect(r09_qualification(offer)).to have_attributes(score: 100, quality: 'unqualified')
    expect(r09_qualification(offer).reasons.join(' ').downcase).to include('team size')
  end

  it 'rejects an incompatible rule atomically instead of saving a field comparison it cannot evaluate' do
    question = r09_question('uses_crm', answer_type: 'boolean', prompt: 'Do you currently use a CRM?')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    rule = { kind: 'score_rule', field: 'uses_crm', operator: 'gte', value: 100, score_delta: 50, priority: 0, enabled: true }

    r09_update_offer(offer, name: 'Must not be saved', rules: [rule])

    expect(response).to have_http_status(:unprocessable_entity)
    get "#{r09_offers_url}/#{offer.fetch('id')}", headers: r09_headers, as: :json
    expect(response.parsed_body).to include('name' => offer.fetch('name'), 'version' => offer.fetch('version'), 'rules' => [])
  end

  it 'uses each Offer rule for the same custom field while keeping both source answers separate' do
    question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
    rule = { kind: 'score_rule', field: 'team_size', operator: 'gte', value: 10, score_delta: 30, priority: 0, enabled: true }
    first = r09_create_offer(r09_configuration(questions: [question], rules: [rule], score_weights: { team_size: 0 }))
    second = r09_create_offer(r09_configuration(name: 'Larger teams', questions: [question], rules: [rule.merge(value: 20)],
                                                score_weights: { team_size: 0 }))
    conversation_a = r09_conversation(offer: first)
    conversation_b = r09_conversation(offer: second)
    r09_receive(conversation_a, 'Hello')
    answer_a, = r09_receive(conversation_a, '12')
    r09_receive(conversation_b, 'Hello')
    expect(r09_qualification(second).evidence_snapshot).not_to have_key('team_size')

    answer_b, = r09_receive(conversation_b, '12')

    expect(r09_qualification(first).score).to eq(30)
    expect(r09_qualification(second).score).to eq(0)
    expect(r09_qualification(first).evidence_snapshot.fetch('team_size')).to include('message_id' => answer_a.id)
    expect(r09_qualification(second).evidence_snapshot.fetch('team_size')).to include('message_id' => answer_b.id)
  end

  it 'rejects reusing the inquiry-volume key for a revenue money field' do
    question = r09_question('lead_volume', answer_type: 'money', prompt: 'What is your monthly revenue?', meaning: 'Monthly revenue', period: 'month')

    post r09_offers_url, headers: r09_headers, params: { offer: r09_configuration(questions: [question]) }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.qualification_offers).to be_empty
  end

  rule_defaults = { kind: 'score_rule', priority: 0, score_delta: 30, enabled: true }.freeze
  [
    { field: 'missing_field', operator: 'gte', value: 10 },
    { field: 'team_size', operator: 'execute', value: 'arbitrary expression' },
    { field: 'team_size', operator: 'gte', value: 'ten' },
    { field: 'team_size', operator: 'gte', value: 10, score_delta: -30 },
    { kind: 'hard_rule', field: 'team_size', operator: 'gte', value: 10, forced_outcome: 'highly_qualified' }
  ].each do |invalid_attributes|
    it "rejects an invalid rule #{invalid_attributes.inspect} without creating partial configuration" do
      question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
      rule = rule_defaults.merge(invalid_attributes)

      post r09_offers_url, headers: r09_headers,
                           params: { offer: r09_configuration(questions: [question], rules: [rule]) }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(account.qualification_offers).to be_empty
      expect(AiLeadEmployee::OfferConfigurationRevision.where(account: account)).to be_empty
    end
  end

  it 'rejects a money rule whose currency differs from the configured field currency' do
    question = r09_question('monthly_revenue', answer_type: 'money', prompt: 'What is your monthly revenue?', period: 'month')
    rule = { kind: 'score_rule', field: 'monthly_revenue', operator: 'gte', value: { amount: '1000000.00', currency: 'KES' },
             score_delta: 30, priority: 0, enabled: true }

    post r09_offers_url, headers: r09_headers,
                         params: { offer: r09_configuration(questions: [question], rules: [rule]) }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(account.qualification_offers).to be_empty
  end
end
