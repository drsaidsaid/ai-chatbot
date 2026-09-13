# frozen_string_literal: true

class AiLeadEmployee::AccountCostAllocation < ApplicationRecord
  self.table_name = 'ai_account_cost_allocations'

  CATEGORIES = %w[hosting payment_processing support].freeze

  belongs_to :account
  belongs_to :recorded_by_platform_app, class_name: 'PlatformApp'

  validates :category, inclusion: { in: CATEGORIES }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :period_started_on, :period_ended_on, presence: true
  validate :period_is_forward
  validate :period_does_not_overlap

  scope :overlapping, lambda { |period_start, period_end|
    where(period_started_on: ..period_end).where(period_ended_on: period_start..)
  }

  private

  def period_is_forward
    return if period_started_on.blank? || period_ended_on.blank? || period_ended_on >= period_started_on

    errors.add(:period_ended_on, 'must not be before the period start')
  end

  def period_does_not_overlap
    return if account_id.blank? || category.blank? || currency.blank? || period_started_on.blank? || period_ended_on.blank?

    overlapping = self.class.where(account_id: account_id, category: category, currency: currency)
                      .where.not(id: id)
                      .overlapping(period_started_on, period_ended_on)
    errors.add(:base, 'Cost allocation periods must not overlap') if overlapping.exists?
  end
end
