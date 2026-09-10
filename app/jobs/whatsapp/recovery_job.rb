class Whatsapp::RecoveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Whatsapp::WebhookReceipt.where(expanded_at: nil).order(:id).limit(100).each { |receipt| recover_record(receipt) { receipt.enqueue } }
    # Retried delivery updates move behind older waiting work. Ordering only by
    # receipt ID would let unresolved statuses monopolize every recovery batch.
    receipt_ids = Whatsapp::WebhookEvent.recoverable.order(Arel.sql('COALESCE(next_attempt_at, created_at)'), :id).limit(100).pluck(:receipt_id)
    Whatsapp::WebhookReceipt.where(id: receipt_ids.uniq).find_each { |receipt| recover_record(receipt) { receipt.enqueue } }
    AiLeadEmployee::OrchestrationIntent.recoverable.order(:updated_at, :id).limit(100).each do |intent|
      recover_record(intent) { AiLeadEmployee::OrchestrationIntentJob.perform_later(intent.id) }
    end
  end

  private

  def recover_record(record)
    yield
  rescue StandardError
    Rails.logger.warn("[WHATSAPP RECOVERY] enqueue_unavailable record_type=#{record.class.name} record_id=#{record.id}")
  end
end
