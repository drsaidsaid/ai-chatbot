# frozen_string_literal: true

class OutboxEffectReceipt < ApplicationRecord
  belongs_to :outbox_event

  validates :consumer, presence: true
  validates :consumer, uniqueness: { scope: :outbox_event_id }

  def self.consume_once!(outbox_event_id:, consumer:)
    transaction(requires_new: true) do
      new(outbox_event_id: outbox_event_id, consumer: consumer).save!(validate: false)
      yield
      true
    end
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
