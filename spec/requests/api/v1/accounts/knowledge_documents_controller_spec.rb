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

  it 'creates a conflict-review proposal without replacing the published Offer price' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Old coaching brochure',
           body: 'The published price for Growth coaching is USD 900.00.',
           source: 'manual_import',
           offer_id: offer.id
         },
         as: :json

    expect(response).to have_http_status(:created)
    proposal = response.parsed_body.fetch('commercial_proposals').sole
    expect(proposal).to include(
      'status' => 'conflict_review',
      'proposed_terms' => include('amount' => '900.00', 'currency' => 'USD'),
      'conflict_details' => include('published_amount' => '1250.00')
    )
    expect(offer.reload.payload.dig('published_commercial_terms', 'amount')).to eq('1250.00')

    post "/api/v1/accounts/#{account.id}/qualification_offers/#{offer.id}/commercial_proposals/#{proposal.fetch('id')}/approve",
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('commercial_terms_draft', 'amount')).to eq('900.00')
    expect(response.parsed_body.dig('published_commercial_terms', 'amount')).to eq('1250.00')
  end

  it 'does not confuse Lead budgets or platform subscription prices with an Offer price' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Commercial notes',
           body: 'The Lead budget is USD 500. The platform subscription plan costs USD 20 per month.',
           offer_id: offer.id
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.fetch('commercial_proposals')).to be_empty
    expect(offer.reload.commercial_term).to be_nil
  end

  it 'extracts standard and promotional facts from authored document revisions for approval' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)

    post "/api/v1/accounts/#{account.id}/knowledge_documents",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Growth coaching prices',
           body: 'The standard price is USD 1250.00. The promotional price is USD 1000.00.',
           offer_ids: [offer.id],
           general_question_access: false
         },
         as: :json

    expect(response).to have_http_status(:created)
    document_id = response.parsed_body.fetch('id')
    first = response.parsed_body.fetch('commercial_proposals').sole
    expect(first.fetch('proposed_terms')).to include(
      'amount' => '1250.00', 'promotion_amount' => '1000.00',
      'proposal_kinds' => contain_exactly('standard', 'promotion')
    )

    patch "/api/v1/accounts/#{account.id}/knowledge_documents/#{document_id}",
          headers: admin.create_new_auth_token,
          params: {
            title: 'Growth coaching prices',
            body: 'The standard price is USD 1300.00.',
            offer_ids: [offer.id],
            general_question_access: false
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('commercial_proposals').length).to eq(2)
  end

  it 'preserves and flags contradictory prices even when no price is published' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Contradictory brochure',
           body: 'The standard price is USD 1250.00. The standard price is USD 1300.00.',
           offer_id: offer.id
         },
         as: :json

    proposal = response.parsed_body.fetch('commercial_proposals').sole
    expect(proposal.fetch('status')).to eq('conflict_review')
    expect(proposal.dig('conflict_details', 'reason')).to include('contradictory')
    expect(proposal.dig('proposed_terms', 'candidates')).to contain_exactly(
      include('proposal_kind' => 'standard', 'amount' => '1250.00', 'currency' => 'USD'),
      include('proposal_kind' => 'standard', 'amount' => '1300.00', 'currency' => 'USD')
    )
  end

  it 'flags every conflicting fact when a later candidate matches the published price' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Mixed brochure revisions',
           body: 'The standard price was USD 900.00. The standard price is USD 1250.00.',
           offer_id: offer.id
         },
         as: :json

    proposal = response.parsed_body.fetch('commercial_proposals').sole
    expect(proposal.fetch('status')).to eq('conflict_review')
    expect(proposal.dig('proposed_terms', 'candidates')).to contain_exactly(
      include('amount' => '900.00', 'currency' => 'USD'),
      include('amount' => '1250.00', 'currency' => 'USD')
    )
  end

  it 'preserves and flags two distinct prices written in one sentence' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Ambiguous price sentence',
           body: 'The standard price is USD 1250.00 or USD 900.00.',
           offer_id: offer.id
         },
         as: :json

    proposal = response.parsed_body.fetch('commercial_proposals').sole
    expect(proposal.fetch('status')).to eq('conflict_review')
    expect(proposal.dig('proposed_terms', 'candidates')).to contain_exactly(
      include('amount' => '1250.00', 'currency' => 'USD'),
      include('amount' => '900.00', 'currency' => 'USD')
    )
  end

  it 'does not silently redenominate an existing standard price from a cross-currency promotion' do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Growth coaching', currency: 'USD', enabled: true)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)

    post "/api/v1/accounts/#{account.id}/knowledge_documents/import",
         headers: admin.create_new_auth_token,
         params: {
           title: 'Promotion in another currency',
           body: 'The promotional price is TZS 100000.00.',
           offer_id: offer.id
         },
         as: :json
    proposal = response.parsed_body.fetch('commercial_proposals').sole

    post "/api/v1/accounts/#{account.id}/qualification_offers/#{offer.id}/commercial_proposals/#{proposal.fetch('id')}/approve",
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body.fetch('error')).to include('currency')
    expect(offer.reload.commercial_term.draft_payload).to include('amount' => '1250.00', 'currency' => 'USD')
  end
end
