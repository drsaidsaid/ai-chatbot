# frozen_string_literal: true

# == Schema Information
#
# Table name: qualification_budget_ranges
#
#  id         :bigint           not null, primary key
#  enabled    :boolean          default(TRUE), not null
#  label      :string           not null
#  max_cents  :integer
#  min_cents  :integer
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  idx_on_account_id_enabled_position_19e6784019    (account_id,enabled,position)
#  index_qualification_budget_ranges_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class QualificationBudgetRange < ApplicationRecord
  belongs_to :account

  validates :label, :position, presence: true
  validate :validate_bounds

  scope :enabled_in_order, -> { where(enabled: true).order(:position, :id) }

  private

  def validate_bounds
    return if min_cents.blank? || max_cents.blank? || min_cents <= max_cents

    errors.add(:max_cents, 'must be greater than or equal to min cents')
  end
end
