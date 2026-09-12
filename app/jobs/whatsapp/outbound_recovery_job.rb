class Whatsapp::OutboundRecoveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Whatsapp::OutboundDelivery.recoverable.order(:updated_at, :id).limit(100).each do |delivery|
      SendReplyJob.perform_later(delivery.message_id) if delivery.recover!
    rescue StandardError
      Rails.logger.warn("[WHATSAPP OUTBOUND] recovery_queue_unavailable delivery_id=#{delivery.id}")
    end

    Whatsapp::OutboundDelivery.retryable_subscription_alerts.order(:updated_at, :id).limit(100).each do |delivery|
      SendReplyJob.perform_later(delivery.message_id) if delivery.retry_subscription_alert!
    rescue StandardError
      Rails.logger.warn("[WHATSAPP OUTBOUND] subscription_alert_retry_unavailable delivery_id=#{delivery.id}")
    end
  end
end
