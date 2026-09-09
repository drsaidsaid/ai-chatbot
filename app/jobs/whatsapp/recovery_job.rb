class Whatsapp::RecoveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Whatsapp::WebhookReceipt.where(expanded_at: nil).order(:id).limit(100).each(&:enqueue)
    # Retried delivery updates move behind older waiting work. Ordering only by
    # receipt ID would let unresolved statuses monopolize every recovery batch.
    receipt_ids = Whatsapp::WebhookEvent.recoverable.order(Arel.sql('COALESCE(next_attempt_at, created_at)'), :id).limit(100).pluck(:receipt_id)
    Whatsapp::WebhookReceipt.where(id: receipt_ids.uniq).find_each(&:enqueue)
    AiLeadEmployee::OrchestrationIntent.pending.order(:id).limit(100).each do |intent|
      AiLeadEmployee::OrchestrationIntentJob.perform_later(intent.id)
    end
  end
end
