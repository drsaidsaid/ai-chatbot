# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::PromotionEligibility do
  it 'reads confirmed eligibility only from current evidence for the selected account Offer' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    contact = create(:contact, account: account)
    offer = AiLeadEmployee::Offer.create!(
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
    conversation = create(:conversation, account: account, contact: contact, offer: offer)
    publish_conditional_promotion(offer, admin)
    old_evidence = create(
      :qualification_evidence,
      account: account,
      contact: contact,
      offer: offer,
      field_key: 'returning_client',
      value: { 'typed_value' => false },
      superseded_at: 1.minute.ago
    )
    current_evidence = create(
      :qualification_evidence,
      account: account,
      contact: contact,
      offer: offer,
      field_key: 'returning_client',
      value: { 'typed_value' => true }
    )

    expect(described_class.new(conversation: conversation, offer: offer.reload).value).to be(true)
    expect(old_evidence).to be_superseded_at
    expect(current_evidence).not_to be_superseded_at
  end

  it 'does not read eligibility through a cross-account Offer' do
    account = create(:account)
    other_account = create(:account)
    conversation = create(:conversation, account: account)
    other_offer = AiLeadEmployee::Offer.create!(
      account: other_account, name: 'Other offer', currency: 'USD', enabled: true
    )

    expect(described_class.new(conversation: conversation, offer: other_offer).value).to be_nil
  end

  it 'ignores evidence older than the configured qualification freshness window' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    contact = create(:contact, account: account)
    offer = conditional_offer(account)
    conversation = create(:conversation, account: account, contact: contact, offer: offer)
    publish_conditional_promotion(offer, admin)
    create(
      :qualification_evidence,
      account: account,
      contact: contact,
      offer: offer,
      field_key: 'returning_client',
      value: { 'typed_value' => true },
      observed_at: 31.days.ago
    )

    expect(described_class.new(conversation: conversation, offer: offer.reload).value).to be_nil
  end

  def publish_conditional_promotion(offer, admin)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: offer,
      attributes: {
        amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC',
        promotion_amount: '1000.00', promotion_starts_at: 1.day.ago.iso8601,
        promotion_ends_at: 1.day.from_now.iso8601, promotion_requires_confirmation: true,
        promotion_eligibility_field: 'returning_client'
      }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: offer, expected_version: term.draft_version, editor: admin)
  end

  def conditional_offer(account)
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
end
