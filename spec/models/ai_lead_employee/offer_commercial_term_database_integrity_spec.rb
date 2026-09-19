# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OfferCommercialTerm do
  # These examples intentionally bypass model validations to prove database-enforced tenant joins.
  # rubocop:disable Rails/SkipsModelValidations
  it 'rejects a commercial term whose account and Offer do not match' do
    account = create(:account)
    other_offer = AiLeadEmployee::Offer.create!(
      account: create(:account), name: 'Other offer', currency: 'USD', enabled: true
    )

    expect do
      described_class.insert_all!(
        [{ account_id: account.id, offer_id: other_offer.id, draft: {}, draft_version: 0,
           created_at: Time.current, updated_at: Time.current }]
      )
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'rejects a revision whose commercial record, Offer and account do not form one scope' do
    account = create(:account)
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Offer', currency: 'USD', enabled: true)
    other_account = create(:account)
    other_offer = AiLeadEmployee::Offer.create!(
      account: other_account, name: 'Other offer', currency: 'USD', enabled: true
    )
    other_term = described_class.create!(account: other_account, offer: other_offer)

    expect do
      AiLeadEmployee::OfferCommercialTermRevision.insert_all!(
        [{ account_id: account.id, offer_id: offer.id, commercial_term_id: other_term.id,
           revision: 1, snapshot: {}, content_digest: 'invalid-scope', published_at: Time.current,
           created_at: Time.current, updated_at: Time.current }]
      )
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'rejects a proposal whose document belongs to another account' do
    account = create(:account)
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Offer', currency: 'USD', enabled: true)
    other_document = create(:knowledge_document, account: create(:account))

    expect do
      AiLeadEmployee::OfferCommercialProposal.insert_all!(
        [{ account_id: account.id, offer_id: offer.id, knowledge_document_id: other_document.id,
           status: 0, source_digest: 'invalid-scope', proposed_terms: {}, conflict_details: {},
           created_at: Time.current, updated_at: Time.current }]
      )
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it 'rejects a proposal whose Offer belongs to another account' do
    account = create(:account)
    document = create(:knowledge_document, account: account)
    other_offer = AiLeadEmployee::Offer.create!(
      account: create(:account), name: 'Other offer', currency: 'USD', enabled: true
    )

    expect do
      AiLeadEmployee::OfferCommercialProposal.insert_all!(
        [{ account_id: account.id, offer_id: other_offer.id, knowledge_document_id: document.id,
           status: 0, source_digest: 'invalid-scope', proposed_terms: {}, conflict_details: {},
           created_at: Time.current, updated_at: Time.current }]
      )
    end.to raise_error(ActiveRecord::InvalidForeignKey)
  end
  # rubocop:enable Rails/SkipsModelValidations
end
