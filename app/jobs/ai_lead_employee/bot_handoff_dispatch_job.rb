# frozen_string_literal: true

class AiLeadEmployee::BotHandoffDispatchJob < ApplicationJob
  class DispatchFailed < StandardError; end

  queue_as :high

  def perform(outbox_event_id)
    event = OutboxEvent.find(outbox_event_id)
    event.with_lock do
      return unless event.pending?

      conversation = event.account.conversations.find(event.payload.fetch('conversation_id'))
      validate_event!(event, conversation)
      dispatched = conversation.dispatch_bot_handoff_event(outbox_event_id: event.id, occurred_at: event.created_at)
      raise DispatchFailed, 'Bot handoff event enqueue failed' if dispatched == false

      event.update!(state: :delivered, attempts: event.attempts + 1, delivered_at: Time.current,
                    failed_at: nil, failure_class: nil)
    end
  rescue StandardError => e
    record_failure(event, e)
    raise
  end

  private

  def validate_event!(event, conversation)
    valid = event.event_type == Conversations::ControlService::BOT_HANDOFF_EVENT_TYPE &&
            event.aggregate == conversation
    raise ActiveRecord::RecordNotFound, 'Invalid bot handoff outbox event' unless valid
  end

  def record_failure(event, error)
    return if event.blank? || !event.persisted?

    event.with_lock do
      return unless event.pending?

      event.update!(attempts: event.attempts + 1, failed_at: Time.current, failure_class: error.class.name)
    end
  end
end
