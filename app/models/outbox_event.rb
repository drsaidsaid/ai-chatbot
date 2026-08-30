# frozen_string_literal: true

# == Schema Information
#
# Table name: outbox_events
#
class OutboxEvent < ApplicationRecord
  belongs_to :account
  belongs_to :aggregate, polymorphic: true

  enum :state, { pending: 0, delivered: 1, failed: 2 }

  validates :event_type, :idempotency_key, presence: true
  validates :idempotency_key, uniqueness: { scope: :account_id }
  validate :validate_account_scope

  private

  def validate_account_scope
    return unless aggregate.respond_to?(:account_id)
    return if aggregate.account_id == account_id

    errors.add(:aggregate, 'must belong to the same account')
  end
end
