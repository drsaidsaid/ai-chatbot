class Whatsapp::WebhookReceipt < ApplicationRecord
  self.table_name = 'whatsapp_webhook_receipts'

  encrypts :raw_body
  has_many :events, class_name: 'Whatsapp::WebhookEvent', foreign_key: :receipt_id, inverse_of: :receipt, dependent: :restrict_with_exception

  validates :raw_body, :body_digest, :verified_routes, presence: true

  def enqueue
    raise ActiveJob::EnqueueError unless Webhooks::WhatsappEventsJob.perform_later(id)
  rescue StandardError
    update!(error_code: 'queue_unavailable')
    Rails.logger.warn("[WHATSAPP RECEIPT] queue_unavailable receipt_id=#{id}")
  end
end
