class Whatsapp::WebhookEvent < ApplicationRecord
  self.table_name = 'whatsapp_webhook_events'

  belongs_to :receipt, class_name: 'Whatsapp::WebhookReceipt'
  belongs_to :account
  belongs_to :inbox
  belongs_to :channel, class_name: 'Channel::Whatsapp'

  enum :state, { pending: 0, processed: 1, ignored: 2, awaiting_message: 3, failed: 4 }
  validates :event_key, :kind, :payload, presence: true

  scope :recoverable, lambda {
    where(state: [:pending, :awaiting_message, :failed]).where('next_attempt_at IS NULL OR next_attempt_at <= ?', Time.current)
  }

  def terminal?
    processed? || ignored?
  end
end
