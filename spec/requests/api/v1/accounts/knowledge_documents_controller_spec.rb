# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Knowledge Documents API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'lets an admin create update publish archive import and test a document', :aggregate_failures do
    post "/api/v1/accounts/#{account.id}/knowledge_documents",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Everything about Online Profits',
           body: 'Online Profits helps businesses grow with marketing automation.',
           used_by_ai_employee: true,
           general_question_access: true
         },
         as: :json

    expect(response).to have_http_status(:created)
    document = KnowledgeDocument.find(response.parsed_body['id'])
    expect(document).to be_draft

    patch "/api/v1/accounts/#{account.id}/knowledge_documents/#{document.id}",
          headers: admin.create_new_auth_token,
          params: { title: 'Online Profits context', body: 'Online Profits provides growth strategy and CRM automation.' },
          as: :json
    expect(response).to have_http_status(:success)
    expect(document.reload.title).to eq('Online Profits context')

    post "/api/v1/accounts/#{account.id}/knowledge_documents/#{document.id}/publish",
         headers: admin.create_new_auth_token,
         as: :json
    expect(document.reload).to be_published

    post "/api/v1/accounts/#{account.id}/knowledge_documents/#{document.id}/test",
         headers: admin.create_new_auth_token,
         params: { question: 'Do you provide CRM automation?' },
         as: :json
    expect(response.parsed_body['answered']).to be(true)
    expect(response.parsed_body['sources'].first['source_kind']).to eq('document')

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: { title: 'Broken import', body: '' },
         as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body['status']).to eq('import_failed')

    post "/api/v1/accounts/#{account.id}/knowledge_documents/#{document.id}/archive",
         headers: admin.create_new_auth_token,
         as: :json
    expect(document.reload).to be_archived
  end

  it 'prevents non-admin operators from reading or changing documents' do
    create(:knowledge_document, account: account)

    get "/api/v1/accounts/#{account.id}/knowledge_documents",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns the full body in the index response so the editor is not hydrated with a truncated draft' do
    body = [
      'About Online Profits',
      ('Online Profits helps WhatsApp-led businesses answer general questions from rich context while keeping exact claims controlled. ' * 16)
    ].join("\n\n")
    document = create(:knowledge_document, account: account, title: 'Online Profits business context', body: body)

    get "/api/v1/accounts/#{account.id}/knowledge_documents",
        headers: admin.create_new_auth_token,
        as: :json

    indexed_document = response.parsed_body.find { |item| item['id'] == document.id }
    expect(indexed_document['body'].length).to eq(body.length)
    expect(indexed_document['body']).to end_with('controlled. ')
  end
end
