# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer evidence lifecycle', type: :request do
  include_context 'with Offer qualification requests'

  it 'qualifies explicit purchase spending capacity and retains its basis and original message' do
    questions = [
      r09_question('budget', answer_type: 'money', prompt: 'What can you spend on this Offer?'),
      r09_question('problem', answer_type: 'text', prompt: 'What problem should we solve?', position: 1),
      r09_question('urgency', answer_type: 'text', prompt: 'How soon do you want this solved?', position: 2),
      r09_question('decision_authority', answer_type: 'boolean', prompt: 'Do you decide this purchase?', position: 3)
    ]
    offer = r09_create_offer(r09_configuration(currency: 'USD', minimum: '1000.00', questions: questions))
    conversation = r09_conversation(offer: offer)

    incoming, = r09_receive(conversation, 'I need more leads now. I am the owner of the agency and can spend $2500.')

    expect(r09_qualification(offer)).to be_highly_qualified
    expect(r09_qualification(offer).evidence_snapshot.fetch('budget')).to include(
      'basis' => 'capacity', 'polarity' => 'positive', 'amount_minor' => 250_000, 'currency' => 'USD', 'message_id' => incoming.id
    )
  end

  [
    'My salary is $2500.',
    'Our revenue is $2500 per month.',
    'I can spend $2500 on groceries.',
    'I cannot spend $2500.',
    'I can spend $2500 if my loan is approved.',
    'My budget is 2500.'
  ].each do |financial_statement|
    it "does not treat #{financial_statement.inspect} as sufficient purchase evidence" do
      offer = r09_create_offer(r09_configuration(currency: 'USD', minimum: '1000.00'))
      conversation = r09_conversation(offer: offer)

      r09_receive(conversation, "I need more leads now. I am the owner of the agency. #{financial_statement}")
      qualification = r09_qualification(offer)

      expect(qualification).not_to be_highly_qualified
      expect(qualification.missing_signals).to include('budget')
      expect(LeadHandoff.where(conversation: conversation)).to be_empty
    end
  end

  it 'retains positive, negative and unknown corrections with source links without changing another Offer' do
    first = r09_create_offer(r09_configuration)
    second = r09_create_offer(r09_configuration(name: 'Sales training'))
    conversation_a = r09_conversation(offer: first)
    conversation_b = r09_conversation(offer: second)
    positive, = r09_receive(conversation_a, 'Bajeti yangu ni TZS 600000.')
    r09_receive(conversation_b, 'Bajeti yangu ni TZS 1000000.')
    other_snapshot = r09_qualification(second).attributes

    negative, = r09_receive(conversation_a, 'Correction: I no longer have any budget.')
    unknown, = r09_receive(conversation_a, 'I have not set a budget.')
    facts = QualificationEvidence.where(account: account, contact: r09_lead, offer_id: first.fetch('id'), signal: :budget).order(:id).to_a

    expect(facts.map { |fact| fact.value.fetch('polarity') }).to eq(%w[positive negative unknown])
    expect(facts.map(&:message_id)).to eq([positive.id, negative.id, unknown.id])
    expect(facts.map(&:superseded_by_id)).to eq([facts[1].id, facts[2].id, nil])
    expect(r09_qualification(first).evidence_snapshot.fetch('budget')).to include('polarity' => 'unknown', 'message_id' => unknown.id)
    expect(r09_qualification(second).attributes).to eq(other_snapshot)

    expect do
      AiLeadEmployee::QualificationService.new(conversation: conversation_a, incoming_message: positive).perform
    end.not_to(change { QualificationEvidence.where(offer_id: first.fetch('id')).count })
    expect(r09_qualification(first).evidence_snapshot.fetch('budget')).to include('message_id' => unknown.id)
  end

  it 'applies a human correction to the explicitly selected Conversation and Offer rather than the latest Conversation' do
    first = r09_create_offer(r09_configuration)
    second = r09_create_offer(r09_configuration(name: 'Sales training'))
    conversation_a = r09_conversation(offer: first)
    conversation_b = r09_conversation(offer: second)
    r09_receive(conversation_a, 'My budget is TZS 600000.')
    r09_receive(conversation_b, 'My budget is TZS 1000000.')
    other_snapshot = r09_qualification(second).evidence_snapshot

    post(
      "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}/evidence",
      headers: r09_headers,
      params: { offer_id: first.fetch('id'), conversation_id: conversation_a.display_id, signal: 'budget', value: 'TZS 250000' },
      as: :json
    )

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('offer_id' => first.fetch('id'))
    corrected = QualificationEvidence.current.find_by!(account: account, contact: r09_lead, offer_id: first.fetch('id'), signal: :budget)
    expect(corrected).to have_attributes(source: 'human', user_id: r09_admin.id, conversation_id: conversation_a.id)
    expect(corrected.value).to include('amount_minor' => 25_000_000, 'currency' => 'TZS')

    r09_receive(conversation_a, 'My budget is TZS 900000.')
    expect(r09_qualification(first).evidence_snapshot.fetch('budget')).to include('evidence_id' => corrected.id, 'source' => 'human')
    expect(r09_qualification(second).evidence_snapshot).to eq(other_snapshot)
  end

  it 'invalidates only the changed Offer then reevaluates retained observations under its new threshold' do
    first = r09_create_offer(r09_configuration)
    second = r09_create_offer(r09_configuration(name: 'Sales training'))
    conversation_a = r09_conversation(offer: first)
    conversation_b = r09_conversation(offer: second)
    incoming, = r09_receive(conversation_a, 'My budget is TZS 600000.')
    r09_receive(conversation_b, 'My budget is TZS 600000.')
    original_evidence = r09_qualification(first).evidence_snapshot
    original_decision = r09_qualification(first).lead_qualification_decisions.last.attributes
    unchanged = r09_qualification(second).attributes
    ranges = first.fetch('budget_ranges').map { |range| range.merge('minimum' => '900000.00') }

    r09_update_offer(first, budget_ranges: ranges)
    expect(response).to have_http_status(:success)
    updated = response.parsed_body
    verify_configuration_invalidation(first, second, original_evidence, unchanged)

    r09_receive(conversation_a, 'Hello')

    expect(r09_qualification(first)).to have_attributes(quality: 'unqualified', configuration_version: updated.fetch('version'), stale_at: nil)
    expect(r09_qualification(first).evidence_snapshot.fetch('budget')).to include('message_id' => incoming.id)
    expect(LeadQualificationDecision.find(original_decision.fetch('id')).attributes).to eq(original_decision)
    expect(r09_qualification(second).attributes).to eq(unchanged)
  end

  it 'does not reinterpret an answer to a question from an obsolete configuration revision' do
    question = r09_question('team_size', answer_type: 'number', prompt: 'How many people work in your team?')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')
    r09_update_offer(offer, questions: [question.merge('prompt' => 'How large is your team?')])
    expect(response).to have_http_status(:success)

    r09_receive(conversation, '12')

    expect(r09_qualification(offer).evidence_snapshot).not_to have_key('team_size')
  end

  it 'rejects a semantic field rewrite after evidence while permitting a wording change' do
    question = r09_question('monthly_revenue', answer_type: 'money', prompt: 'What is your monthly revenue?', period: 'month')
    offer = r09_create_offer(r09_configuration(questions: [question]))
    conversation = r09_conversation(offer: offer)
    r09_receive(conversation, 'Hello')
    r09_receive(conversation, 'TZS 1200000')
    expect(r09_qualification(offer).evidence_snapshot).to have_key('monthly_revenue')

    r09_update_offer(offer, questions: [question.merge('period' => 'year', 'meaning' => 'Annual revenue')])
    expect(response).to have_http_status(:unprocessable_entity)
    r09_update_offer(offer, questions: [question.merge('prompt' => 'How much revenue does the business earn monthly?')])
    expect(response).to have_http_status(:success)
  end

  it 'does not resurrect default questions when every saved question is disabled' do
    configuration = r09_configuration
    configuration['questions'].each { |question| question['enabled'] = false }
    offer = r09_create_offer(configuration)
    conversation = r09_conversation(offer: offer)

    _incoming, replied = r09_receive(conversation, 'Hello')

    expect(replied.outbound_message.additional_attributes.dig('ai_lead_employee', 'qualification', 'next_question')).to be_nil
    expect(replied.outbound_message.content).not_to include('?')
  end

  def verify_configuration_invalidation(first, second, original_evidence, unchanged)
    expect(r09_qualification(first).stale_at).to be_present
    expect(r09_qualification(first).evidence_snapshot).to eq(original_evidence)
    expect(r09_qualification(second).attributes).to eq(unchanged)
  end
end
