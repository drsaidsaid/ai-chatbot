# frozen_string_literal: true

# == Schema Information
#
# Table name: qualification_questions
#
#  id         :bigint           not null, primary key
#  enabled    :boolean          default(TRUE), not null
#  metadata   :jsonb            not null
#  position   :integer          default(0), not null
#  prompt     :text             not null
#  signal     :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  idx_on_account_id_enabled_position_81d2a5e994           (account_id,enabled,position)
#  index_qualification_questions_on_account_id             (account_id)
#  index_qualification_questions_on_account_id_and_signal  (account_id,signal) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class QualificationQuestion < ApplicationRecord
  SIGNALS = {
    business_type: 0,
    problem: 1,
    lead_volume: 2,
    urgency: 3,
    budget: 4,
    decision_authority: 5,
    contact_details: 6
  }.freeze

  belongs_to :account

  enum signal: SIGNALS

  validates :signal, :prompt, :position, presence: true
  validates :signal, uniqueness: { scope: :account_id }

  scope :enabled_in_order, -> { where(enabled: true).order(:position, :id) }
end
