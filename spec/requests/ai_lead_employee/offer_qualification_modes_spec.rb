# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Optional business-defined Offer qualification', type: :request do
  include_context 'with Offer qualification requests'

  it 'keeps not-configured and disabled Offers from fabricating a Qualification' do
    not_configured = r09_create_offer(mode_configuration('Information only', 'not_configured'))
    disabled = r09_create_offer(mode_configuration('Paused qualification', 'disabled'))

    [not_configured, disabled].each do |offer|
      conversation = r09_conversation(offer: offer)
      result = AiLeadEmployee::OfferQualificationService.new(conversation: conversation).perform

      expect(result).to have_attributes(
        qualification: nil,
        qualification_mode: offer.fetch('qualification_mode'),
        next_question: nil,
        offer_id: offer.fetch('id')
      )
      expect(LeadQualification.where(account: account, contact: r09_lead, offer_id: offer.fetch('id'))).not_to exist

      get(
        "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}",
        headers: r09_headers, params: { offer_id: offer.fetch('id') }
      )
      expect(response.parsed_body).to include(
        'qualification_mode' => offer.fetch('qualification_mode'),
        'quality' => nil,
        'assessment' => {
          'fit' => include('status' => 'not_evaluated'),
          'readiness' => include('status' => 'not_evaluated'),
          'action_eligibility' => include('status' => 'not_evaluated')
        }
      )

      get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: r09_headers
      expect(response.parsed_body.fetch('lead_qualification')).to include(
        'qualification_mode' => offer.fetch('qualification_mode'), 'quality' => nil,
        'assessment' => include('fit' => include('status' => 'not_evaluated'))
      )
    end
  end

  it 'separates fit, readiness and action eligibility without universal gates', :aggregate_failures do
    offer = r09_create_offer(enabled_configuration)
    conversation = r09_conversation(offer: offer)

    record_evidence(conversation, offer, 'problem', 'We need more qualified inquiries')
    first = qualification_payload(offer)
    expect(first).to include('quality' => 'qualified', 'next_question' => 'How soon would you like to begin?')
    expect(first.fetch('assessment')).to include(
      'fit' => include('status' => 'met', 'missing_fields' => []),
      'readiness' => include('status' => 'missing', 'missing_fields' => ['urgency']),
      'action_eligibility' => include('status' => 'missing', 'missing_fields' => ['contact_details'])
    )

    record_evidence(conversation, offer, 'contact_details', '+255700222333')
    second = qualification_payload(offer)
    expect(second.fetch('assessment')).to include(
      'fit' => include('status' => 'met'),
      'readiness' => include('status' => 'missing'),
      'action_eligibility' => include('status' => 'met')
    )
    expect(second.fetch('next_question')).to eq('How soon would you like to begin?')

    record_evidence(conversation, offer, 'urgency', 'We are ready now')
    final = qualification_payload(offer)
    expect(final.fetch('assessment').values.pluck('status')).to eq(%w[met met met])
    expect(final.fetch('next_question')).to be_nil

    qualification = r09_qualification(offer)
    expect(qualification.missing_signals).to eq([])
    expect(qualification.evidence_snapshot.keys).not_to include('budget', 'decision_authority')
    expect(qualification.lead_qualification_decisions.last.assessment).to eq(qualification.assessment)
  end

  it 'permits the configured sales-call action without a Highly Qualified-only gate' do
    offer = r09_create_offer(enabled_configuration)
    conversation = r09_conversation(offer: offer)
    record_evidence(conversation, offer, 'problem', 'We need more qualified inquiries')
    record_evidence(conversation, offer, 'contact_details', '+255700222333')
    record_evidence(conversation, offer, 'urgency', 'We are ready now')
    qualification = r09_qualification(offer)

    expect(qualification).to be_qualified
    expect(qualification).not_to be_highly_qualified
    result = AiLeadEmployee::HighlyQualifiedHandoffService.new(
      conversation: conversation,
      qualification: qualification,
      qualification_context: latest_context(conversation, qualification),
      defer_alert_delivery: true
    ).perform

    expect(result.handoff).to be_persisted
    expect(result.handoff.qualification_snapshot.fetch('assessment').dig('action_eligibility', 'status')).to eq('met')
  end

  def mode_configuration(name, mode)
    r09_configuration(name: name, questions: [], budget_ranges: [], rules: [], legacy_contract: false,
                      qualification_mode: mode, next_step: { kind: 'answer_only' })
  end

  def enabled_configuration
    questions = [
      r09_question('problem', answer_type: 'text', prompt: 'What outcome do you need?', purpose: 'fit'),
      r09_question('urgency', answer_type: 'text', prompt: 'How soon would you like to begin?', purpose: 'readiness'),
      r09_question('contact_details', answer_type: 'text', prompt: 'How should our sales team contact you?', purpose: 'action_eligibility')
    ]
    rules = [
      requirement('problem', 'fit', 'positive'),
      requirement('urgency', 'readiness', 'positive'),
      requirement('contact_details', 'action_eligibility', 'known')
    ]
    r09_configuration(
      questions: questions, rules: rules, budget_ranges: [], score_weights: {}, legacy_contract: false,
      score_thresholds: { qualified: 0, highly_qualified: 100 }, qualification_mode: 'enabled',
      next_step: { kind: 'sales_call' }
    )
  end

  def requirement(field, dimension, operator)
    { kind: 'requirement', dimension: dimension, field: field, operator: operator,
      value: nil, priority: 0, enabled: true }
  end

  def record_evidence(conversation, offer, field, value)
    post(
      "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}/evidence",
      headers: r09_headers,
      params: { offer_id: offer.fetch('id'), conversation_id: conversation.display_id, field_key: field, value: value },
      as: :json
    )
    expect(response).to have_http_status(:success)
  end

  def qualification_payload(offer)
    get(
      "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}",
      headers: r09_headers, params: { offer_id: offer.fetch('id') }
    )
    expect(response).to have_http_status(:success)
    response.parsed_body
  end

  def latest_context(conversation, qualification)
    AiLeadEmployee::OfferDeliveryContext.capture(
      conversation: conversation,
      qualification: qualification,
      decision: qualification.lead_qualification_decisions.order(:id).last,
      next_question_key: nil
    )
  end
end
