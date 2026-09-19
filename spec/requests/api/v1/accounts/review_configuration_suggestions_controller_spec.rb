# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Review configuration suggestions API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, account: account) }
  let(:offer) do
    AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Sales consultation',
      currency: 'TZS',
      enabled: true,
      configuration: {
        'qualification_mode' => 'enabled',
        'next_step' => { 'kind' => 'sales_call' },
        'questions' => [{
          'key' => 'sales_call_agreement', 'label' => 'Book a call?', 'answer_type' => 'boolean',
          'required' => true, 'purpose' => 'action_eligibility', 'enabled' => true
        }],
        'budget_ranges' => [],
        'rules' => [],
        'score_weights' => {},
        'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
      }
    )
  end
  let(:conversation) do
    create(
      :conversation,
      account: account,
      contact: contact,
      offer: offer,
      assignee: nil,
      status: :pending,
      control_state: :ai_active
    )
  end
  let(:qualification) do
    create(
      :lead_qualification,
      account: account,
      contact: contact,
      offer: offer,
      quality: :qualified,
      score: 70,
      assessment: {
        'fit' => { 'status' => 'not_required', 'missing_fields' => [], 'reasons' => [] },
        'readiness' => { 'status' => 'not_required', 'missing_fields' => [], 'reasons' => [] },
        'action_eligibility' => { 'status' => 'met', 'missing_fields' => [], 'reasons' => [] }
      },
      evidence_snapshot: {
        'sales_call_agreement' => { 'typed_value' => true, 'polarity' => 'positive' }
      }
    )
  end

  before do
    admin
    account.update!(settings: { 'ai_lead_employee' => { 'human_operator_id' => operator.id } })
  end

  it 'captures feedback from a real sales handoff and exposes it in the administrator queue without changing the Offer', :aggregate_failures do
    original_configuration = offer.configuration.deep_dup
    handoff = create_real_sales_handoff

    expect(handoff).to be_persisted
    expect(conversation.reload.assignee).to eq(operator)

    2.times do
      post "/api/v1/accounts/#{account.id}/lead_handoffs/#{handoff.id}/propose_configuration_suggestion",
           headers: operator.create_new_auth_token,
           params: { category: 'poor_fit', suggestion: 'Review whether the current fit rules admit this Lead.' },
           as: :json
      expect(response).to have_http_status(:success)
    end

    suggestion = handoff.reload.configuration_suggestion
    expect(ReviewConfigurationSuggestion.where(lead_handoff: handoff).count).to eq(1)
    expect(suggestion).to have_attributes(
      human_review_request_id: nil,
      source_message_id: nil,
      offer_id: offer.id,
      category: 'poor_fit',
      status: 'pending'
    )
    expect(JSON.parse(suggestion.evidence)).to include('quality' => 'qualified', 'score' => 70)
    expect(offer.reload.configuration).to eq(original_configuration)

    replacement_offer = AiLeadEmployee::Offer.create!(account: account, name: 'Replacement', currency: 'TZS')
    conversation.update!(offer: replacement_offer)
    AccountUser.find_by!(account: account, user: operator).destroy!

    get "/api/v1/accounts/#{account.id}/review_configuration_suggestions",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to contain_exactly(
      include(
        'id' => suggestion.id,
        'source_type' => 'lead_handoff',
        'source_id' => handoff.id,
        'status' => 'pending',
        'conversation_display_id' => conversation.display_id
      )
    )

    post "/api/v1/accounts/#{account.id}/review_configuration_suggestions/#{suggestion.id}/review",
         headers: admin.create_new_auth_token,
         params: { outcome: 'reviewed', decision_note: 'Assess during the next rules review.' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(suggestion.reload).to have_attributes(
      status: 'reviewed',
      reviewed_by_user_id: admin.id,
      offer_id: offer.id,
      proposed_by_user_id: operator.id
    )
    expect(offer.reload.configuration).to eq(original_configuration)
  end

  it 'keeps the pending administrator queue and other operators outside the handoff scope', :aggregate_failures do
    other_operator = create(:user, account: account, role: :agent)
    handoff = create(
      :lead_handoff,
      account: account,
      contact: contact,
      conversation: conversation,
      lead_qualification: qualification,
      assignee: operator
    )
    conversation.update!(assignee: operator)

    get "/api/v1/accounts/#{account.id}/review_configuration_suggestions",
        headers: operator.create_new_auth_token,
        as: :json
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/accounts/#{account.id}/lead_handoffs/#{handoff.id}/propose_configuration_suggestion",
         headers: other_operator.create_new_auth_token,
         params: { category: 'not_ready', suggestion: 'Review readiness rules.' },
         as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(handoff.reload.configuration_suggestion).to be_nil
  end

  def create_real_sales_handoff
    decision = qualification.record_decision!
    context = AiLeadEmployee::OfferDeliveryContext.capture(
      conversation: conversation,
      qualification: qualification,
      decision: decision,
      next_question_key: nil
    )
    AiLeadEmployee::HighlyQualifiedHandoffService.new(
      conversation: conversation,
      qualification: qualification,
      qualification_context: context,
      defer_alert_delivery: true
    ).perform.handoff
  end
end
