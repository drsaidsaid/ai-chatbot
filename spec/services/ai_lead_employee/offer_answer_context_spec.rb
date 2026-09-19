# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OfferAnswerContext do
  it 'accepts only the current selected Offer revision' do
    account = create(:account)
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Coaching', currency: 'USD', enabled: true)
    conversation = create(:conversation, account: account, offer: offer)
    context = described_class.capture(conversation: conversation, offer: offer)

    expect(described_class.new(conversation: conversation, context: context).failure_code).to be_nil

    offer.update!(configuration_version: offer.configuration_version + 1)
    expect(described_class.new(conversation: conversation, context: context).failure_code).to eq('offer_configuration_changed')
  end

  it 'invalidates queued pricing when its promotion is no longer applicable at final send' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Coaching', currency: 'USD', enabled: true)
    conversation = create(:conversation, account: account, offer: offer)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: {
        amount: '1200.00', currency: 'USD', quote_required: false, timezone: 'UTC',
        promotion_amount: '900.00', promotion_starts_at: '2026-09-19T08:00:00Z',
        promotion_ends_at: '2026-09-19T09:00:00Z'
      }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)

    travel_to Time.zone.parse('2026-09-19T08:59:59Z') do
      pricing = AiLeadEmployee::OfferPricingResolver.new(account: account, offer: offer.reload).perform
      context = described_class.capture(conversation: conversation, offer: offer, sources: pricing.sources)
      expect(described_class.new(conversation: conversation, context: context).failure_code).to be_nil

      travel 2.seconds
      expect(described_class.new(conversation: conversation, context: context).failure_code).to eq('offer_price_not_current')
    end
  end

  it 'invalidates queued pricing after a newer commercial revision is published' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Coaching', currency: 'USD', enabled: true)
    conversation = create(:conversation, account: account, offer: offer)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer, attributes: { amount: '1200.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)
    pricing = AiLeadEmployee::OfferPricingResolver.new(account: account, offer: offer.reload).perform
    context = described_class.capture(conversation: conversation, offer: offer, sources: pricing.sources)

    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      expected_version: term.reload.draft_version,
      attributes: { amount: '1300.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)

    expect(described_class.new(conversation: conversation, context: context).failure_code).to eq('offer_configuration_changed')
  end

  it 'invalidates a queued promotion when current eligibility is revoked before final send' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    contact = create(:contact, account: account)
    offer = conditional_offer(account)
    conversation = create(:conversation, account: account, contact: contact, offer: offer)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: {
        amount: '1200.00', currency: 'USD', quote_required: false, timezone: 'UTC',
        promotion_amount: '900.00', promotion_starts_at: 1.day.ago.iso8601,
        promotion_ends_at: 1.day.from_now.iso8601, promotion_requires_confirmation: true,
        promotion_eligibility_field: 'returning_client'
      }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)
    evidence = create(
      :qualification_evidence,
      account: account,
      contact: contact,
      offer: offer,
      field_key: 'returning_client',
      value: { 'typed_value' => true }
    )
    pricing = AiLeadEmployee::OfferPricingResolver.new(
      account: account,
      offer: offer.reload,
      promotion_eligible: AiLeadEmployee::PromotionEligibility.new(conversation: conversation, offer: offer).value
    ).perform
    context = described_class.capture(conversation: conversation, offer: offer, sources: pricing.sources)

    evidence.update!(superseded_at: Time.current)
    create(
      :qualification_evidence,
      account: account,
      contact: contact,
      offer: offer,
      field_key: 'returning_client',
      value: { 'typed_value' => false }
    )

    expect(described_class.new(conversation: conversation, context: context).failure_code).to eq('offer_price_not_current')
  end

  def conditional_offer(account)
    AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Coaching',
      currency: 'USD',
      enabled: true,
      configuration: {
        'questions' => [
          {
            'key' => 'returning_client', 'meaning' => 'Returning client', 'answer_type' => 'boolean',
            'prompt' => 'Have you bought before?', 'position' => 0, 'enabled' => true, 'required' => false
          }
        ]
      }
    )
  end
end
