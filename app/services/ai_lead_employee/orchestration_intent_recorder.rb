# frozen_string_literal: true

class AiLeadEmployee::OrchestrationIntentRecorder
  def initialize(message:, enqueue_review_alerts: true, enforce_launch_gate: true, enqueue: true)
    @message = message
    @enqueue_review_alerts = enqueue_review_alerts
    @enforce_launch_gate = enforce_launch_gate
    @enqueue = enqueue
  end

  def perform
    return create_unsupported_media_review if unsupported_media_message?
    return unless eligible_message?

    intent = find_or_create_intent
    enqueue_intent(intent) if @created_intent && @enqueue
    intent
  end

  private

  attr_reader :message, :enqueue_review_alerts, :enforce_launch_gate

  def eligible_message?
    persisted_incoming_whatsapp_text? &&
      supported_content? &&
      account_scope_consistent? &&
      live_ai_enabled?
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

  def unsupported_media_message?
    persisted_incoming_whatsapp? && message.content_attributes['is_unsupported'] == true
  end

  def persisted_incoming_whatsapp?
    message&.persisted? &&
      message.incoming? &&
      message.inbox.channel.is_a?(Channel::Whatsapp) &&
      account_scope_consistent?
  end

  def account_scope_consistent?
    message.account_id == message.conversation.account_id
  end

  def conversation_allows_ai?(conversation)
    conversation.ai_active? &&
      conversation.open? &&
      conversation.assignee_id.blank? &&
      live_ai_enabled? &&
      message.id > conversation.ai_resume_after_message_id
  end

  def live_ai_enabled?
    !enforce_launch_gate || AiLeadEmployee::LaunchGate.live_ai_enabled?(message.account)
  end

  def find_or_create_intent
    @created_intent = false
    conversation = message.conversation.reload

    conversation.with_lock do
      return unless conversation_allows_ai?(conversation)

      key = idempotency_key(conversation)
      existing_intent = AiLeadEmployee::OrchestrationIntent.find_by(account: message.account, idempotency_key: key)
      return existing_intent if existing_intent.present?

      @created_intent = true
      AiLeadEmployee::OrchestrationIntent.create!(
        account: message.account,
        conversation: conversation,
        triggering_message: message,
        observed_control_version: conversation.control_version,
        idempotency_key: key
      )
    end
  rescue ActiveRecord::RecordNotUnique
    @created_intent = false
    AiLeadEmployee::OrchestrationIntent.find_by!(account: message.account, idempotency_key: idempotency_key(conversation))
  end

  def enqueue_intent(intent)
    AiLeadEmployee::OrchestrationIntentJob.perform_later(intent.id)
  end

  def create_unsupported_media_review
    conversation = message.conversation.reload

    conversation.with_lock do
      return unless conversation_allows_ai?(conversation)

      AiLeadEmployee::HumanReviewRequestService.new(
        conversation: conversation,
        lead_message: message,
        reason: 'unsupported_media',
        enqueue_alerts: enqueue_review_alerts
      ).perform
    end
    nil
  end

  def idempotency_key(conversation)
    "ai-orchestration/#{message.account_id}/#{message.conversation_id}/#{message.id}/#{conversation.control_version}"
  end
end
