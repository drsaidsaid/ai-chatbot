# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OfferPricingResolver do
  include ActiveSupport::Testing::TimeHelpers

  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:offer) do
    AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Growth programme',
      currency: 'USD',
      enabled: true,
      configuration: {
        'questions' => [
          {
            'key' => 'returning_client', 'meaning' => 'Returning client', 'answer_type' => 'boolean',
            'prompt' => 'Have you bought from us before?', 'position' => 0, 'enabled' => true, 'required' => false
          }
        ]
      }
    )
  end

  it 'uses timezone-aware effective windows and quotes a conditional promotion only with confirmed eligibility', :aggregate_failures do
    publish(
      amount: '1250.00', currency: 'USD', quote_required: false,
      effective_from: '2026-09-19T09:00', effective_until: '2026-10-01T09:00', timezone: 'Africa/Dar_es_Salaam',
      conditions: 'Includes onboarding.', pricing_url: 'https://example.test/buy',
      promotion_amount: '1000.00', promotion_starts_at: '2026-09-20T09:00', promotion_ends_at: '2026-09-21T09:00',
      promotion_conditions: 'For returning clients.', promotion_requires_confirmation: true,
      promotion_eligibility_field: 'returning_client'
    )

    before_start = resolve(at: Time.utc(2026, 9, 19, 5, 59, 59))
    standard = resolve(at: Time.utc(2026, 9, 19, 6, 0, 0))
    uncertain_promotion = resolve(at: Time.utc(2026, 9, 20, 6, 0, 0))
    confirmed_promotion = resolve(at: Time.utc(2026, 9, 20, 6, 0, 0), promotion_eligible: true)
    after_promotion = resolve(at: Time.utc(2026, 9, 21, 6, 0, 0), promotion_eligible: true)

    expect(before_start).to have_attributes(answer: nil, refusal_reason: 'price_not_current')
    expect(standard.answer).to include('USD 1250.00', 'Includes onboarding.', 'https://example.test/buy')
    expect(standard.variant).to eq('standard')
    expect(uncertain_promotion.variant).to eq('standard')
    expect(confirmed_promotion.answer).to include('USD 1000.00', 'For returning clients.')
    expect(confirmed_promotion.variant).to eq('promotion')
    expect(after_promotion.variant).to eq('standard')
    expect(confirmed_promotion.sources.first).to include(
      type: 'offer_commercial_terms', offer_id: offer.id, commercial_revision: 1, pricing_variant: 'promotion'
    )
  end

  it 'answers quote-required mode without inventing an amount' do
    publish(currency: 'TZS', quote_required: true, timezone: 'Africa/Dar_es_Salaam',
            conditions: 'Final scope must be reviewed.', pricing_url: 'https://example.test/request-quote')

    result = resolve(at: Time.utc(2026, 9, 19, 12))

    expect(result.answer).to include('requires a quote', 'Final scope must be reviewed.', 'https://example.test/request-quote')
    expect(result.answer).not_to match(/TZS\s+\d/)
    expect(result.variant).to eq('quote_required')
  end

  it 'honors a daylight-saving timezone transition at the exact effective boundary' do
    publish(
      amount: '1250.00', currency: 'USD', quote_required: false,
      effective_from: '2026-03-08T03:00', timezone: 'America/New_York'
    )

    expect(resolve(at: Time.utc(2026, 3, 8, 6, 59, 59)).refusal_reason).to eq('price_not_current')
    expect(resolve(at: Time.utc(2026, 3, 8, 7, 0, 0)).answer).to include('USD 1250.00')
  end

  it 'refuses to resolve an Offer through another Business Account' do
    publish(amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC')
    other_account = create(:account)

    result = described_class.new(account: other_account, offer: offer.reload).perform

    expect(result).to have_attributes(answer: nil, refusal_reason: 'offer_not_selected')
  end

  def publish(attributes)
    term = AiLeadEmployee::CommercialTerms.save_draft!(offer: offer, attributes: attributes)
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)
  end

  def resolve(at:, promotion_eligible: nil)
    described_class.new(account: account, offer: offer.reload, at: at, promotion_eligible: promotion_eligible).perform
  end
end
