# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Typed alternative Offer requirements', type: :request do
  include_context 'with Offer qualification requests'

  it 'validates a bounded typed all/any group and retains it in the versioned Offer payload' do
    offer = r09_create_offer(group_configuration)

    expect(offer.fetch('requirement_groups')).to include(
      include('dimension' => 'fit', 'any' => include(include('all' => be_an(Array))))
    )

    invalid = group_configuration(requirement_groups: [{ 'dimension' => 'fit', 'any' => [] }])
    post r09_offers_url, headers: r09_headers, params: { offer: invalid }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch('error')).to include('between one and eight')

    malformed = [
      [{ 'dimension' => 'fit', 'any' => [{ 'field' => 'unknown_field', 'operator' => 'eq', 'value' => true }] }],
      [{ 'dimension' => 'fit', 'any' => [{ 'any' => [{ 'any' => [{ 'field' => 'business_status',
                                                                   'operator' => 'eq', 'value' => 'no_business' }] }] }] }]
    ]
    malformed.each do |groups|
      post r09_offers_url, headers: r09_headers,
                           params: { offer: group_configuration(requirement_groups: groups) }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
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

  it 'admits a sales handoff only when the alternative, expert willingness and explicit agreement are met' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)
    record(conversation, offer, 'business_status', 'no_business')
    record(conversation, offer, 'expert_willingness', true)
    record(conversation, offer, 'sales_call_agreement', true)
    qualification = r09_qualification(offer)

    expect(handoff_for(conversation, qualification).handoff).to be_persisted
  end

  it 'blocks sales handoff for false expert willingness or absent agreement' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)
    record(conversation, offer, 'business_status', 'no_business')
    record(conversation, offer, 'expert_willingness', false)
    qualification = r09_qualification(offer)

    expect(qualification.assessment.dig('fit', 'status')).to eq('not_met')
    expect(handoff_for(conversation, qualification).handoff).to be_nil
  end

  it 'blocks sales handoff for wrong-currency or unknown operating-business revenue' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)
    record(conversation, offer, 'business_status', 'operating_business')
    record(conversation, offer, 'expert_willingness', true)
    post "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}/evidence",
         headers: r09_headers,
         params: { offer_id: offer.fetch('id'), conversation_id: conversation.display_id,
                   field_key: 'monthly_business_revenue_tzs', value: 'USD 500000' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    record(conversation, offer, 'sales_call_agreement', true)
    qualification = r09_qualification(offer)

    expect(qualification.assessment.dig('fit', 'status')).not_to eq('met')
    expect(handoff_for(conversation, qualification).handoff).to be_nil
  end

  it 'revokes current handoff authority after corrected evidence no longer meets the alternative' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)
    record(conversation, offer, 'business_status', 'no_business')
    record(conversation, offer, 'expert_willingness', true)
    record(conversation, offer, 'sales_call_agreement', true)
    expect(r09_qualification(offer).assessment.dig('fit', 'status')).to eq('met')

    record(conversation, offer, 'business_status', 'operating_business')
    record(conversation, offer, 'monthly_business_revenue_tzs', 'TZS 1200000')
    corrected = r09_qualification(offer)

    expect(corrected.assessment.dig('fit', 'status')).to eq('not_met')
    expect(handoff_for(conversation, corrected).handoff).to be_nil
  end

  it 'does not let a fit group suppress the same field when it is required for action eligibility' do
    configuration = group_configuration
    configuration['questions'].find { |question| question['key'] == 'business_status' }['purpose'] = 'action_eligibility'
    offer = r09_create_offer(configuration)
    conversation = r09_conversation(offer: offer)
    AiLeadEmployee::OfferQualificationService.new(conversation: conversation).perform

    expect(r09_qualification(offer).assessment.dig('action_eligibility', 'missing_fields')).to include('business_status')
  end

  it 'stales a previous qualification decision when an alternative group edit creates a new revision' do
    offer = r09_create_offer(group_configuration)
    conversation = r09_conversation(offer: offer)
    record(conversation, offer, 'business_status', 'no_business')
    record(conversation, offer, 'expert_willingness', true)
    qualification = r09_qualification(offer)

    r09_update_offer(offer, name: 'Edited alternative fit')
    expect(response).to have_http_status(:success)
    expect(qualification.reload.stale_at).to be_present
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
      { 'dimension' => 'fit', 'any' => [
        { 'field' => 'business_status', 'operator' => 'eq', 'value' => 'no_business' },
        { 'all' => [
          { 'field' => 'business_status', 'operator' => 'eq', 'value' => 'operating_business' },
          { 'field' => 'monthly_business_revenue_tzs', 'operator' => 'lt',
            'value' => { 'amount' => '1000000', 'currency' => 'TZS' } }
        ] }
      ] },
      { 'dimension' => 'action_eligibility', 'all' => [
        { 'field' => 'sales_call_agreement', 'operator' => 'eq', 'value' => true }
      ] }
    ]
    expert_rule = { kind: 'requirement', dimension: 'fit', field: 'expert_willingness', operator: 'eq', value: true,
                    priority: 0, enabled: true }
    r09_configuration(name: 'Alternative fit', questions: questions, rules: [expert_rule], requirement_groups: groups,
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

  def handoff_for(conversation, qualification)
    context = AiLeadEmployee::OfferDeliveryContext.capture(
      conversation: conversation, qualification: qualification,
      decision: qualification.lead_qualification_decisions.order(:id).last, next_question_key: nil
    )
    AiLeadEmployee::HighlyQualifiedHandoffService.new(
      conversation: conversation, qualification: qualification, qualification_context: context, defer_alert_delivery: true
    ).perform
  end
end
