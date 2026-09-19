# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer commercial terms', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:offers_url) { "/api/v1/accounts/#{account.id}/qualification_offers" }

  it 'keeps edited terms inactive until an admin explicitly publishes them' do
    offer = create_offer
    original_offer_version = offer.fetch('version')

    patch "#{offers_url}/#{offer.fetch('id')}/commercial_terms",
          headers: headers,
          params: {
            commercial_terms: {
              amount: '1250.50', currency: 'USD', quote_required: false,
              effective_from: '2026-09-19T09:00', effective_until: '2026-10-01T09:00',
              timezone: 'Africa/Dar_es_Salaam', conditions: 'Includes onboarding.',
              pricing_url: 'https://example.test/buy'
            }
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'published_commercial_terms' => nil,
      'commercial_terms_draft' => include('amount' => '1250.50', 'currency' => 'USD', 'draft_version' => 1)
    )
    expect(AiLeadEmployee::Offer.find(offer.fetch('id')).configuration_version).to eq(original_offer_version)

    post "#{offers_url}/#{offer.fetch('id')}/commercial_terms/publish",
         headers: headers,
         params: { draft_version: 1 },
         as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.fetch('published_commercial_terms')).to include(
      'amount' => '1250.50', 'currency' => 'USD', 'quote_required' => false,
      'timezone' => 'Africa/Dar_es_Salaam', 'conditions' => 'Includes onboarding.',
      'pricing_url' => 'https://example.test/buy', 'revision' => 1
    )
    expect(response.parsed_body.fetch('version')).to eq(original_offer_version + 1)
    expect(AiLeadEmployee::OfferCommercialTermRevision.where(offer_id: offer.fetch('id')).count).to eq(1)
  end

  it 'does not expose or mutate another Business Account commercial record' do
    offer = create_offer
    other_account = create(:account)
    other_admin = create(:user, account: other_account, role: :administrator)

    patch "/api/v1/accounts/#{other_account.id}/qualification_offers/#{offer.fetch('id')}/commercial_terms",
          headers: other_admin.create_new_auth_token,
          params: {
            commercial_terms: { amount: '1.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
          },
          as: :json

    expect(response).to have_http_status(:not_found)
    expect(AiLeadEmployee::OfferCommercialTerm.where(offer_id: offer.fetch('id'))).to be_empty
  end

  it 'rejects a stale draft update instead of overwriting a newer edit' do
    offer = create_offer
    path = "#{offers_url}/#{offer.fetch('id')}/commercial_terms"
    terms = { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }

    patch path, headers: headers, params: { commercial_terms: terms }, as: :json
    expect(response).to have_http_status(:success)

    patch path,
          headers: headers,
          params: { draft_version: 1, commercial_terms: terms.merge(amount: '1300.00') },
          as: :json
    expect(response).to have_http_status(:success)

    patch path,
          headers: headers,
          params: { draft_version: 1, commercial_terms: terms.merge(amount: '1400.00') },
          as: :json

    expect(response).to have_http_status(:conflict)
    expect(AiLeadEmployee::Offer.find(offer.fetch('id')).commercial_term.draft_payload['amount']).to eq('1300.00')
  end

  def create_offer
    post offers_url,
         headers: headers,
         params: {
           offer: {
             name: 'Growth coaching', currency: 'USD', enabled: true, qualification_mode: 'disabled',
             next_step: { kind: 'answer_only' }, questions: [], budget_ranges: [], rules: [], score_weights: {},
             score_thresholds: { qualified: 60, highly_qualified: 80 }
           }
         },
         as: :json
    expect(response).to have_http_status(:created)
    response.parsed_body
  end
end
