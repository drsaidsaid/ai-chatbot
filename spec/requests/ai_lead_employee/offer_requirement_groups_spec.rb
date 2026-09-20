# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Typed alternative Offer requirements', type: :request do
  include_context 'with Offer qualification requests'

  it 'validates a bounded typed all/any group and retains it in the versioned Offer payload' do
    offer = r09_create_offer(group_configuration)

    expect(offer.fetch('requirement_groups')).to include(
      include('dimension' => 'fit', 'all' => include(include('any' => be_an(Array))))
    )

    invalid = group_configuration(requirement_groups: [{ 'dimension' => 'fit', 'any' => [] }])
    post r09_offers_url, headers: r09_headers, params: { offer: invalid }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch('error')).to include('between one and eight')
  end

  it 'does not ask operating-business revenue when the no-business alternative is known satisfied' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)

    record(conversation, offer, 'business_status', 'no_business')
    record(conversation, offer, 'expert_willingness', true)
    record(conversation, offer, 'sales_call_agreement', true)
    payload = qualification_payload(offer)

    expect(payload.fetch('assessment')['fit']).to include('status' => 'met', 'missing_fields' => [])
    expect(payload.fetch('next_question')).to be_nil
  end

  it 'requires revenue only for the operating-business branch and revokes fit after corrected evidence' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)

    record(conversation, offer, 'business_status', 'operating_business')
    record(conversation, offer, 'expert_willingness', true)
    first = qualification_payload(offer)
    expect(first.fetch('assessment')['fit']).to include('status' => 'missing', 'missing_fields' => ['monthly_business_revenue_tzs'])
    expect(first.fetch('next_question')).to include('monthly revenue')

    record(conversation, offer, 'monthly_business_revenue_tzs', 'TZS 500000')
    expect(qualification_payload(offer).fetch('assessment').dig('fit', 'status')).to eq('met')

    record(conversation, offer, 'monthly_business_revenue_tzs', 'TZS 1200000')
    expect(qualification_payload(offer).fetch('assessment').dig('fit', 'status')).to eq('not_met')
  end

  def group_configuration(requirement_groups: nil) # rubocop:disable Metrics/MethodLength
    questions = [
      r09_question('business_status', answer_type: 'choice', options: %w[no_business operating_business uncertain],
                                      prompt: 'Do you currently run a business?'),
      r09_question('monthly_business_revenue_tzs', answer_type: 'money', required: false, position: 1,
                                                   prompt: 'What is your business monthly revenue in TZS?'),
      r09_question('expert_willingness', answer_type: 'boolean', position: 2,
                                         prompt: 'Would you build a business using your own expertise?'),
      r09_question('sales_call_agreement', answer_type: 'boolean', position: 3, purpose: 'action_eligibility',
                                           prompt: 'Would you like a sales call?')
    ]
    groups = requirement_groups || [
      { 'dimension' => 'fit', 'all' => [
        { 'any' => [
          { 'field' => 'business_status', 'operator' => 'eq', 'value' => 'no_business' },
          { 'all' => [
            { 'field' => 'business_status', 'operator' => 'eq', 'value' => 'operating_business' },
            { 'field' => 'monthly_business_revenue_tzs', 'operator' => 'lt',
              'value' => { 'amount' => '1000000', 'currency' => 'TZS' } }
          ] }
        ] },
        { 'field' => 'expert_willingness', 'operator' => 'eq', 'value' => true }
      ] },
      { 'dimension' => 'action_eligibility', 'all' => [
        { 'field' => 'sales_call_agreement', 'operator' => 'eq', 'value' => true }
      ] }
    ]
    r09_configuration(name: 'Alternative fit', questions: questions, rules: [], requirement_groups: groups,
                      score_weights: {}, budget_ranges: [], legacy_contract: false,
                      score_thresholds: { qualified: 0, highly_qualified: 100 }, next_step: { kind: 'sales_call' })
  end

  def record(conversation, offer, field, value)
    r09_record_offer_evidence(conversation, offer, field, value)
  end

  def qualification_payload(offer)
    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}", headers: r09_headers, params: { offer_id: offer.fetch('id') }
    response.parsed_body
  end
end
