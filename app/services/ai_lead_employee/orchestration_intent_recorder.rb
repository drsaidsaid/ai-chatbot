# frozen_string_literal: true

class AiLeadEmployee::OrchestrationIntentRecorder
  def initialize(message:)
    @message = message
  end

  def perform
    return unless eligible_message?

    intent = find_or_create_intent
    enqueue_intent(intent) if @created_intent
    intent
  end

  private

  attr_reader :message

  def eligible_message?
    persisted_incoming_whatsapp_text? &&
      supported_content? &&
      account_scope_consistent?
  end

  def persisted_incoming_whatsapp_text?
    message&.persisted? &&
      message.incoming? &&
      message.text? &&
      message.inbox.channel.is_a?(Channel::Whatsapp)
  end

  def supported_content?
    message.content.present? && message.content_attributes['is_unsupported'] != true
  end

  def account_scope_consistent?
    message.account_id == message.conversation.account_id
  end

  def find_or_create_intent
    existing_intent = AiLeadEmployee::OrchestrationIntent.find_by(account: message.account, idempotency_key: idempotency_key)
    return existing_intent if existing_intent.present?

    @created_intent = true
    AiLeadEmployee::OrchestrationIntent.create!(
      account: message.account,
      conversation: message.conversation,
      triggering_message: message,
      observed_control_version: message.conversation.control_version,
      idempotency_key: idempotency_key
    )
  rescue ActiveRecord::RecordNotUnique
    @created_intent = false
    AiLeadEmployee::OrchestrationIntent.find_by!(account: message.account, idempotency_key: idempotency_key)
  end

  def enqueue_intent(intent)
    AiLeadEmployee::OrchestrationIntentJob.perform_later(intent.id)
  end

  def idempotency_key
    "ai-orchestration/#{message.account_id}/#{message.conversation_id}/#{message.id}/#{message.conversation.control_version}"
  end
end
