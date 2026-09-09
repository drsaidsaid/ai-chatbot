# frozen_string_literal: true

class AiLeadEmployee::OutboxDispatchJob < ApplicationJob
  DeliveryFailed = Class.new(StandardError)

  EVENT_TYPES = [
    AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOX_EVENT_TYPE,
    AiLeadEmployee::FollowUpDeliveryService::OUTBOX_EVENT_TYPE
  ].freeze

  queue_as :high

  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(outbox_event_id = nil)
    events(outbox_event_id).find_each { |event| dispatch(event) }
  end

  private

  def events(outbox_event_id)
    scope = OutboxEvent.pending.where(event_type: EVENT_TYPES)
    outbox_event_id.present? ? scope.where(id: outbox_event_id) : scope
  end

  def dispatch(event)
    return discard_ineligible_follow_up!(event) unless follow_up_dispatchable?(event)

    event.with_lock do
      return unless event.pending?

      event.update!(attempts: event.attempts + 1)
    end

    SendReplyJob.perform_now(event.payload.fetch('message_id'))
    raise_if_message_failed!(event)
    mark_delivered!(event)
  rescue StandardError => e
    event.update_columns(failure_class: e.class.name, failed_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    raise
  end

  def mark_delivered!(event)
    event.with_lock do
      event.update!(state: :delivered, delivered_at: Time.current, failure_class: nil, failed_at: nil)
      mark_follow_up_sent!(event)
    end
  end

  def raise_if_message_failed!(event)
    message = event.account.messages.find(event.payload.fetch('message_id'))
    return unless message.failed?

    raise DeliveryFailed, message.external_error.presence || 'Message delivery failed'
  end

  def mark_follow_up_sent!(event)
    follow_up_id = event.payload['follow_up_id']
    return if follow_up_id.blank?

    follow_up = LeadFollowUp.find(follow_up_id)
    follow_up.update!(status: :sent, sent_at: Time.current) if follow_up.pending?
  end

  def follow_up_dispatchable?(event)
    follow_up_id = event.payload['follow_up_id']
    return true if follow_up_id.blank?

    follow_up = LeadFollowUp.find_by(id: follow_up_id, account_id: event.account_id)
    return false unless follow_up&.pending?

    compatible_follow_up?(follow_up) && !follow_up_opted_out?(follow_up)
  end

  def compatible_follow_up?(follow_up)
    conversation = follow_up.conversation
    conversation.ai_active? && conversation.open? && conversation.assignee_id.blank? &&
      conversation.control_version == follow_up.control_version
  end

  def follow_up_opted_out?(follow_up)
    LeadFollowUpOptOut.exists?(account: follow_up.account, contact: follow_up.contact)
  end

  def discard_ineligible_follow_up!(event)
    event.update!(state: :failed, failure_class: 'FollowUpCancelled', failed_at: Time.current)
  end
end
