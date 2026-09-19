# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Human Review Requests API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: agent) }
  let(:lead_message) do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, content: 'Do you do VIP onboarding?')
  end
  let!(:request_record) { create(:human_review_request, account: account, conversation: conversation, lead_message: lead_message) }

  it 'shows the operator queue to a Human Operator' do
    get "/api/v1/accounts/#{account.id}/human_review_requests",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.first).to include(
      'id' => request_record.id,
      'question' => 'Do you do VIP onboarding?',
      'status' => 'open',
      'conversation_display_id' => conversation.display_id
    )
  end

  it 'does not resolve a request with an automated outgoing answer' do
    answer = create(
      :message,
      :bot_message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      content: 'Automated answer'
    )

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: { human_answer_message_id: answer.id, propose_knowledge: false },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(request_record.reload).to be_open
  end

  it 'resolves a request with a human reply and separately creates a draft knowledge proposal', :aggregate_failures do
    answer = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      message_type: :outgoing,
      sender: agent,
      content: 'Yes, VIP onboarding is available after approval.'
    )

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: {
           human_answer_message_id: answer.id,
           resolution_kind: 'send_reply'
         },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload).to be_resolved
    expect(request_record.human_answer_message).to eq(answer)
    expect(request_record.knowledge_item).to be_nil

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
         headers: agent.create_new_auth_token,
         params: { source_kind: 'offer', title: 'VIP onboarding' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload.knowledge_item).to be_draft
    expect(request_record.knowledge_item.question).to eq('Do you do VIP onboarding?')
    expect(request_record.knowledge_item.answer).to eq('Yes, VIP onboarding is available after approval.')
    expect(request_record.knowledge_item.source_kind).to eq('offer')

    result_before_approval = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account,
      question: 'Do you do VIP onboarding?'
    ).perform
    expect(result_before_approval).to be_refused

    request_record.knowledge_item.approve!
    result_after_approval = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account,
      question: 'Do you do VIP onboarding?'
    ).perform
    expect(result_after_approval.answer).to eq('Yes, VIP onboarding is available after approval.')
  end

  it 'creates the outgoing answer while resolving and proposing an Approved Answer', :aggregate_failures do
    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: {
           answer: 'VIP onboarding is available for qualified leads.',
           resolution_kind: 'send_reply'
         },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload).to be_resolved
    expect(request_record.human_answer_message.content).to eq('VIP onboarding is available for qualified leads.')
    expect(request_record.human_answer_message).not_to be_private
    expect(request_record.knowledge_item).to be_nil
  end

  it 'reports a late provider failure even when outbound acceptance remains recorded' do
    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: { answer: 'We will review the request.', resolution_kind: 'send_reply' },
         as: :json

    expect(response.parsed_body).to include('reply_outcome' => 'reply_pending_delivery')

    Whatsapp::OutboundDelivery.create!(
      account: account,
      conversation: conversation,
      message: request_record.reload.human_answer_message,
      observed_control_version: conversation.control_version,
      state: :accepted,
      provider_message_id: 'wamid.accepted',
      accepted_at: Time.current
    )
    Whatsapp::MessageStatusProjector.new(
      message: request_record.human_answer_message.reload,
      status: {
        status: 'failed',
        timestamp: 1.minute.from_now.to_i.to_s,
        errors: [{ code: 13_101 }]
      }
    ).perform

    expect(request_record.human_answer_message.whatsapp_outbound_delivery.reload).to be_accepted

    get "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response.parsed_body).to include('reply_outcome' => 'reply_delivery_failed')
    expect(response.parsed_body.fetch('reply_delivery')).to include(
      'outcome' => 'reply_delivery_failed',
      'provider_status' => 'failed',
      'authority_state' => 'accepted',
      'failure_code' => '13101',
      'recoverable' => false
    )
  end

  it 'records a private resolution without queuing a Lead reply, then proposes one offer-scoped draft separately', :aggregate_failures do
    request_record.update!(question: 'Can I get a refund?')

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: {
           answer: 'Refund decisions need an operator review.',
           resolution_kind: 'internal_note'
         },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'resolution_kind' => 'internal_note',
      'reply_outcome' => 'private_note_saved',
      'knowledge_proposal_outcome' => 'not_requested'
    )
    expect(request_record.reload.human_answer_message).to be_private
    expect(request_record.knowledge_item).to be_nil

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
         headers: agent.create_new_auth_token,
         params: {
           source_kind: 'refund',
           title: 'Refund review guidance',
           answer: 'Refund requests are assessed under the published policy.'
         },
         as: :json

    expect(response).to have_http_status(:success)
    proposal = request_record.reload.knowledge_item
    expect(proposal).to be_draft
    expect(proposal.answer).to eq('Refund requests are assessed under the published policy.')
    expect(proposal.metadata).to include(
      'offer_ids' => [],
      'proposed_from_human_review_request_id' => request_record.id
    )
    expect(proposal.metadata).not_to have_key('source_message_id')

    proposal.approve!
    answer = AiLeadEmployee::KnowledgeAnswerService.new(
      account: account,
      question: 'Can I get a refund?'
    ).perform
    expect(answer.answer).to eq('Refund requests are assessed under the published policy.')
    expect(answer.answer).not_to include('operator review')
    expect(response.parsed_body).to include('knowledge_proposal_outcome' => 'draft_proposed')
  end

  it 'makes retrying a public resolution and knowledge proposal safe', :aggregate_failures do
    params = {
      answer: 'Our refund policy is reviewed case by case.',
      resolution_kind: 'send_reply'
    }

    2.times do
      post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
           headers: agent.create_new_auth_token,
           params: params,
           as: :json
      expect(response).to have_http_status(:success)
    end

    expect(request_record.reload.human_answer_message).not_to be_private
    expect(conversation.messages.where(content: params[:answer]).count).to eq(1)

    2.times do
      post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
           headers: agent.create_new_auth_token,
           params: { source_kind: 'refund', title: 'Refund policy' },
           as: :json
      expect(response).to have_http_status(:success)
    end

    expect(
      KnowledgeItem.where(
        "metadata ->> 'proposed_from_human_review_request_id' = ?",
        request_record.id.to_s
      ).count
    ).to eq(1)
  end

  it 'keeps the resolved review recoverable when reusable knowledge cannot yet be proposed', :aggregate_failures do
    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
         headers: agent.create_new_auth_token,
         params: {
           source_kind: 'refund',
           title: 'Refund policy',
           answer: 'Refund requests are assessed under the published policy.'
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(request_record.reload).to be_open
    expect(request_record.knowledge_item).to be_nil

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: { answer: 'A team member will review the refund request.', resolution_kind: 'internal_note' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload).to be_resolved

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
         headers: agent.create_new_auth_token,
         params: {
           source_kind: 'refund',
           title: 'Refund policy',
           answer: 'Refund requests are assessed under the published policy.'
         },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload.knowledge_item).to be_draft
  end

  it 'rejects an unsupported knowledge source without losing the resolved review' do
    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: { answer: 'A team member will review the refund request.', resolution_kind: 'internal_note' },
         as: :json

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
         headers: agent.create_new_auth_token,
         params: { source_kind: 'unsupported', title: 'Refund policy', answer: 'Safe reusable answer.' },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(request_record.reload).to be_resolved
    expect(request_record.knowledge_item).to be_nil
  end

  it 'captures poor-fit feedback for administrator review without changing rules or exposing a private note', :aggregate_failures do
    offer = AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Growth coaching',
      currency: 'TZS',
      configuration: {
        'qualification_mode' => 'enabled',
        'questions' => [],
        'budget_ranges' => [],
        'rules' => [{ 'kind' => 'hard_rule', 'field' => 'region', 'operator' => 'eq', 'value' => 'TZ' }],
        'score_weights' => {},
        'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
      }
    )
    conversation.update!(offer: offer)
    request_record.update!(question: 'This Lead may be a poor fit because they are outside the configured region.')
    original_configuration = offer.configuration.deep_dup

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/resolve",
         headers: agent.create_new_auth_token,
         params: { answer: 'Private note: do not expose this text.', resolution_kind: 'internal_note' },
         as: :json

    2.times do
      post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_configuration_suggestion",
           headers: agent.create_new_auth_token,
           params: { category: 'poor_fit', suggestion: 'Review whether the configured region rule is still correct.' },
           as: :json
      expect(response).to have_http_status(:success)
    end

    suggestion = request_record.reload.configuration_suggestion
    expect(ReviewConfigurationSuggestion.where(human_review_request: request_record).count).to eq(1)
    expect(suggestion).to have_attributes(
      status: 'pending',
      category: 'poor_fit',
      offer_id: offer.id,
      source_message_id: lead_message.id,
      evidence: request_record.question
    )
    expect(suggestion.evidence).not_to include('Private note')
    expect(offer.reload.configuration).to eq(original_configuration)

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/review_configuration_suggestion",
         headers: agent.create_new_auth_token,
         params: { outcome: 'reviewed' },
         as: :json
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/review_configuration_suggestion",
         headers: admin.create_new_auth_token,
         params: { outcome: 'reviewed', decision_note: 'Review during the next configuration update.' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(suggestion.reload).to have_attributes(status: 'reviewed', reviewed_by_user_id: admin.id)
    expect(offer.reload.configuration).to eq(original_configuration)
  end

  it 'does not expose or resolve another operator\'s assigned review' do
    other_operator = create(:user, account: account, role: :agent)

    get "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}",
        headers: other_operator.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'supports administrator assignment and assigned operator rejection from the Review workspace', :aggregate_failures do
    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/assign",
         headers: admin.create_new_auth_token,
         params: { assigned_user_id: agent.id },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload.assigned_user).to eq(agent)

    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/reject",
         headers: agent.create_new_auth_token,
         params: { operator_answer: 'Do not use this request as knowledge.' },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload).to be_rejected
    expect(request_record.operator_answer).to eq('Do not use this request as knowledge.')
  end
end
