# frozen_string_literal: true

class AiLeadEmployee::OfferCommercialProposal < ApplicationRecord
  self.table_name = 'offer_commercial_proposals'

  belongs_to :account
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer'
  belongs_to :knowledge_document
  belongs_to :reviewed_by, class_name: 'User', optional: true

  enum status: { pending: 0, conflict_review: 1, approved: 2, rejected: 3 }

  validates :source_digest, presence: true, uniqueness: { scope: [:knowledge_document_id, :offer_id] }
  validate :same_business_account

  def payload
    {
      id: id,
      offer_id: offer_id,
      knowledge_document_id: knowledge_document_id,
      status: status,
      source_digest: source_digest,
      proposed_terms: proposed_terms,
      conflict_details: conflict_details,
      reviewed_at: reviewed_at,
      reviewed_by: reviewed_by && { id: reviewed_by.id, name: reviewed_by.name }
    }
  end

  private

  def same_business_account
    return if offer&.account_id == account_id && knowledge_document&.account_id == account_id

    errors.add(:base, 'Commercial proposal must stay inside one Business Account')
  end
end
