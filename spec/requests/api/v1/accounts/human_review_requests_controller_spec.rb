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

  it 'records a private resolution without queuing a Lead reply, then proposes one offer-scoped draft separately', :aggregate_failures do
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
         params: { source_kind: 'refund', title: 'Refund review guidance' },
         as: :json

    expect(response).to have_http_status(:success)
    proposal = request_record.reload.knowledge_item
    expect(proposal).to be_draft
    expect(proposal.metadata).to include(
      'offer_ids' => [],
      'proposed_from_human_review_request_id' => request_record.id,
      'source_message_id' => request_record.human_answer_message_id
    )
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
    expect(conversation.messages.where(content: params[:answer])).to have(1).item

    2.times do
      post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/propose_knowledge",
           headers: agent.create_new_auth_token,
           params: { source_kind: 'refund', title: 'Refund policy' },
           as: :json
      expect(response).to have_http_status(:success)
    end

    expect(KnowledgeItem.where("metadata ->> 'proposed_from_human_review_request_id' = ?", request_record.id.to_s)).to have(1).item
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
