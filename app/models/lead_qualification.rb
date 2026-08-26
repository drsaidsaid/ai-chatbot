# frozen_string_literal: true

# == Schema Information
#
# Table name: lead_qualifications
#
#  id                    :bigint           not null, primary key
#  configuration_version :integer          default(1), not null
#  evidence_snapshot     :jsonb            not null
#  follow_up_state       :integer          default("no_follow_up"), not null
#  last_evaluated_at     :datetime         not null
#  missing_signals       :jsonb            not null
#  quality               :integer          default("unknown"), not null
#  reasons               :jsonb            not null
#  score                 :integer          default(0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  contact_id            :bigint           not null
#
# Indexes
#
#  index_lead_qualifications_on_account_id                 (account_id)
#  index_lead_qualifications_on_account_id_and_contact_id  (account_id,contact_id) UNIQUE
#  index_lead_qualifications_on_account_id_and_quality     (account_id,quality)
#  index_lead_qualifications_on_contact_id                 (contact_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#
class LeadQualification < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  has_many :bookings, dependent: :destroy_async
  has_many :lead_qualification_decisions, dependent: :destroy_async

  enum quality: {
    unknown: 0,
    unqualified: 1,
    low_qualified: 2,
    qualified: 3,
    highly_qualified: 4
  }
  enum follow_up_state: {
    no_follow_up: 0,
    nurture: 1,
    human_review: 2,
    call_booked: 3,
    closed: 4
  }

  validates :quality, :follow_up_state, :score, :configuration_version, :last_evaluated_at, presence: true
  validates :contact_id, uniqueness: { scope: :account_id }
  validate :validate_account_scope

  def record_decision!
    lead_qualification_decisions.create!(
      account: account,
      contact: contact,
      quality: quality,
      follow_up_state: follow_up_state,
      score: score,
      reasons: reasons,
      missing_signals: missing_signals,
      evidence_snapshot: evidence_snapshot,
      configuration_version: configuration_version,
      decided_at: last_evaluated_at
    )
  end

  private

  def validate_account_scope
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
  end
end
