# frozen_string_literal: true

# == Schema Information
#
# Table name: lead_qualification_decisions
#
#  id                    :bigint           not null, primary key
#  configuration_version :integer          not null
#  decided_at            :datetime         not null
#  evidence_snapshot     :jsonb            not null
#  follow_up_state       :integer          not null
#  missing_signals       :jsonb            not null
#  quality               :integer          not null
#  reasons               :jsonb            not null
#  score                 :integer          not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  contact_id            :bigint           not null
#  lead_qualification_id :bigint           not null
#
# Indexes
#
#  idx_lead_qualification_decisions_on_lead                     (account_id,contact_id,decided_at)
#  index_lead_qualification_decisions_on_account_id             (account_id)
#  index_lead_qualification_decisions_on_contact_id             (contact_id)
#  index_lead_qualification_decisions_on_lead_qualification_id  (lead_qualification_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (lead_qualification_id => lead_qualifications.id)
#
class LeadQualificationDecision < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :lead_qualification

  enum quality: LeadQualification.qualities
  enum follow_up_state: LeadQualification.follow_up_states

  validates :quality, :follow_up_state, :score, :configuration_version, :decided_at, presence: true
end
