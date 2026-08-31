# frozen_string_literal: true

# == Schema Information
#
# Table name: outbox_events
#
#  id              :bigint           not null, primary key
#  aggregate_type  :string           not null
#  attempts        :integer          default(0), not null
#  delivered_at    :datetime
#  event_type      :string           not null
#  failed_at       :datetime
#  failure_class   :string
#  idempotency_key :string           not null
#  payload         :jsonb            not null
#  state           :integer          default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  aggregate_id    :bigint           not null
#
# Indexes
#
#  index_outbox_events_on_account_id                           (account_id)
#  index_outbox_events_on_account_id_and_event_type_and_state  (account_id,event_type,state)
#  index_outbox_events_on_account_id_and_idempotency_key       (account_id,idempotency_key) UNIQUE
#  index_outbox_events_on_aggregate                            (aggregate_type,aggregate_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
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
