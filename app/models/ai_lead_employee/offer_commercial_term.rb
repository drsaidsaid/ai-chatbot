# frozen_string_literal: true

class AiLeadEmployee::OfferCommercialTerm < ApplicationRecord
  self.table_name = 'offer_commercial_terms'

  belongs_to :account
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer'
  belongs_to :published_revision, class_name: 'AiLeadEmployee::OfferCommercialTermRevision', optional: true
  has_many :revisions, class_name: 'AiLeadEmployee::OfferCommercialTermRevision',
                       foreign_key: :commercial_term_id, dependent: :restrict_with_exception,
                       inverse_of: :commercial_term

  validates :offer_id, uniqueness: true
  validates :draft_version, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :offer_belongs_to_account
  validate :published_revision_belongs_to_term

  def draft_payload
    return nil if draft.blank?

    AiLeadEmployee::CommercialTerms.public_snapshot(draft).merge('draft_version' => draft_version)
  end

  def published_payload
    return unless published_revision

    AiLeadEmployee::CommercialTerms.public_snapshot(published_revision.snapshot).merge(
      'revision' => published_revision.revision,
      'published_at' => published_revision.published_at.iso8601
    )
  end

  private

  def offer_belongs_to_account
    errors.add(:offer, 'must belong to the Business Account') if offer && offer.account_id != account_id
  end

  def published_revision_belongs_to_term
    return unless published_revision
    return if published_revision.account_id == account_id && published_revision.offer_id == offer_id &&
              published_revision.commercial_term_id == id

    errors.add(:published_revision, 'must belong to the same Business Account and Offer commercial record')
  end
end
