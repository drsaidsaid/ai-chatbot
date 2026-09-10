# frozen_string_literal: true

class AiLeadEmployee::OutboxDispatchJob < ApplicationJob
  EVENT_TYPES = [
    AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOX_EVENT_TYPE,
    AiLeadEmployee::FollowUpDeliveryService::OUTBOX_EVENT_TYPE
  ].freeze

  queue_as :high

  def perform(outbox_event_id = nil)
    scope = OutboxEvent.pending.where(event_type: EVENT_TYPES)
    scope = scope.where(id: outbox_event_id) if outbox_event_id
    scope.order(:id).limit(100).each { |event| dispatch(event) }
  end

  private

  def dispatch(event)
    message = event.account.messages.find(event.payload.fetch('message_id'))
    unless event.aggregate_type == 'Message' && event.aggregate_id == message.id && message.whatsapp_outbound_delivery
      event.update!(state: :failed, failure_class: 'InvalidDelivery', failed_at: Time.current)
      return
    end

    SendReplyJob.perform_now(message.id)
    delivery = message.whatsapp_outbound_delivery.reload
    delivery.with_lock { delivery.publish! }
  rescue ActiveRecord::RecordNotFound, KeyError
    event.update!(state: :failed, failure_class: 'InvalidDelivery', failed_at: Time.current)
  rescue StandardError
    # The Message delivery owns retry/uncertainty. A queue batch must keep making
    # progress after one record fails, without granting a second provider attempt.
    Rails.logger.warn("[WHATSAPP OUTBOUND] outbox_recovery_pending event_id=#{event.id}")
  end
end
