# frozen_string_literal: true

class AiLeadEmployee::OfferCommercialTermRevision < ApplicationRecord
  self.table_name = 'offer_commercial_term_revisions'

  belongs_to :account
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer'
  belongs_to :commercial_term, class_name: 'AiLeadEmployee::OfferCommercialTerm', inverse_of: :revisions
  belongs_to :published_by, class_name: 'User', optional: true

  validates :revision, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :offer_id }
  validates :content_digest, presence: true
  validate :same_business_account

  def readonly?
    persisted?
  end

  private

  def same_business_account
    return unless account && offer && commercial_term
    return if offer.account_id == account_id && commercial_term.account_id == account_id && commercial_term.offer_id == offer_id

    errors.add(:base, 'Commercial revision must stay inside one Business Account and Offer')
  end
end
