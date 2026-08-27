# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Knowledge Items API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'lets an admin add edit approve reject and deactivate knowledge' do
    post "/api/v1/accounts/#{account.id}/knowledge_items",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Pricing',
           question: 'What is the setup price?',
           answer: 'Setup is $20.',
           source_kind: 'pricing'
         },
         as: :json

    expect(response).to have_http_status(:created)
    item = KnowledgeItem.find(response.parsed_body['id'])
    expect(item).to be_draft

    patch "/api/v1/accounts/#{account.id}/knowledge_items/#{item.id}",
          headers: admin.create_new_auth_token,
          params: { answer: 'Setup starts at $20.' },
          as: :json
    expect(response).to have_http_status(:success)
    expect(item.reload.answer).to eq('Setup starts at $20.')

    post "/api/v1/accounts/#{account.id}/knowledge_items/#{item.id}/approve",
         headers: admin.create_new_auth_token,
         as: :json
    expect(item.reload).to be_approved

    post "/api/v1/accounts/#{account.id}/knowledge_items/#{item.id}/reject",
         headers: admin.create_new_auth_token,
         as: :json
    expect(item.reload).to be_rejected

    post "/api/v1/accounts/#{account.id}/knowledge_items/#{item.id}/deactivate",
         headers: admin.create_new_auth_token,
         as: :json
    expect(item.reload).to be_inactive
  end

  it 'prevents a Human Operator without admin access from changing knowledge' do
    expect do
      post "/api/v1/accounts/#{account.id}/knowledge_items",
           headers: agent.create_new_auth_token,
           params: {
             title: 'FAQ',
             question: 'Can I book a call?',
             answer: 'Yes.',
             source_kind: 'faq'
           },
           as: :json
    end.not_to change(KnowledgeItem, :count)

    expect(response).to have_http_status(:unauthorized)
  end

  it 'prevents a Human Operator without admin access from reading knowledge' do
    create(:knowledge_item, account: account)

    get "/api/v1/accounts/#{account.id}/knowledge_items",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'marks conflicting Approved Answers for the same exact claim' do
    first = create(:knowledge_item, account: account, source_kind: :pricing, question: 'What is setup pricing?', answer: 'Setup is $20.')
    second = create(:knowledge_item, account: account, source_kind: :pricing, question: 'What is setup pricing?', answer: 'Setup is $30.')

    get "/api/v1/accounts/#{account.id}/knowledge_items",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    payload = response.parsed_body.index_by { |item| item['id'] }
    expect(payload[first.id]['conflict_ids']).to contain_exactly(second.id)
    expect(payload[second.id]['conflict_ids']).to contain_exactly(first.id)
  end
end
