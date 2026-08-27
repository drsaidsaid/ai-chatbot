# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Human Review Requests API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }
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

  it 'resolves a request with the human answer and optional draft knowledge proposal', :aggregate_failures do
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
           propose_knowledge: true,
           source_kind: 'offer',
           title: 'VIP onboarding'
         },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload).to be_resolved
    expect(request_record.human_answer_message).to eq(answer)
    expect(request_record.knowledge_item).to be_draft
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
           send_to_lead: true,
           propose_knowledge: true,
           source_kind: 'eligibility',
           title: 'VIP onboarding eligibility'
         },
         as: :json

    expect(response).to have_http_status(:success)
    expect(request_record.reload).to be_resolved
    expect(request_record.human_answer_message.content).to eq('VIP onboarding is available for qualified leads.')
    expect(request_record.human_answer_message).not_to be_private
    expect(request_record.knowledge_item).to be_draft
    expect(request_record.knowledge_item.source_kind).to eq('eligibility')
  end

  it 'supports assignment and rejection from the Review workspace', :aggregate_failures do
    post "/api/v1/accounts/#{account.id}/human_review_requests/#{request_record.id}/assign",
         headers: agent.create_new_auth_token,
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
