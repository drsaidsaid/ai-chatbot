# frozen_string_literal: true

class AiLeadEmployee::Orchestration::IntentProcessor
  PROVIDER_SYSTEM_PROMPT = [
    'Answer the lead only from the approved business source supplied.',
    'Do not add facts, pricing, guarantees, or policies not present in the source.',
    'If the source is insufficient, respond with exactly: REVIEW_REQUIRED.'
  ].join(' ')
  BLOCK_REASONS = AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS

  FINAL_CHECKS = [
    [:tenant_scope_mismatch, :tenant_scope_mismatch?],
    [:stale_control_version, :stale_control_version?],
    [:incompatible_control_state, :incompatible_control_state?],
    [:ineligible_inbox_status, :ineligible_inbox_status?],
    [:assigned_to_human_operator, :assigned_to_human_operator?],
    [:opted_out, :opted_out?],
    [:human_reply_after_trigger, :human_reply_after_trigger?]
  ].freeze

  def initialize(intent:)
    @intent = intent
  end

  def perform
    @outbound_message_delivery_id = nil
    processed_intent = ActiveRecord::Base.transaction do
      intent.lock!
      return intent if intent.terminal?

      conversation.lock!
      intent.attempts += 1

      block_reason = final_block_reason
      return block_intent!(block_reason) if block_reason.present?

      process_grounded_answer!
    end
    enqueue_outbound_message_delivery
    processed_intent
  rescue AiLeadEmployee::AiProvider::ProviderFailure => e
    AiLeadEmployee::Orchestration::ProviderFailureHandler.new(intent: intent, failure: e).perform
  end

  private

  attr_reader :intent

  delegate :conversation, :triggering_message, :account, to: :intent

  def final_block_reason
    reason, = FINAL_CHECKS.find { |(_, predicate)| send(predicate) }
    BLOCK_REASONS[reason]
  end

  def tenant_scope_mismatch?
    conversation.account_id != intent.account_id ||
      triggering_message.account_id != intent.account_id ||
      triggering_message.conversation_id != conversation.id
  end

  def stale_control_version?
    conversation.control_version != intent.observed_control_version
  end

  def incompatible_control_state?
    !conversation.ai_active?
  end

  def ineligible_inbox_status?
    !conversation.open?
  end

  def assigned_to_human_operator?
    conversation.assignee_id.present?
  end

  def opted_out?
    LeadFollowUpOptOut.exists?(account: account, contact: conversation.contact)
  end

  def human_reply_after_trigger?
    conversation.messages
                .where('id > ?', triggering_message.id)
                .where(message_type: Message.message_types[:outgoing], private: false)
                .to_a
                .any? { |message| human_response?(message) }
  end

  def human_response?(message)
    message.content_attributes['automation_rule_id'].blank? &&
      message.additional_attributes['campaign_id'].blank? &&
      (message.sender.is_a?(User) || message.content_attributes['external_echo'].present?)
  end

  def process_grounded_answer!
    answer_result = AiLeadEmployee::KnowledgeAnswerService.new(account: account, question: triggering_message.content).perform
    return request_review!(answer_result.refusal_reason) if answer_result.refused?

    provider_response = build_provider_answer(answer_result)
    return request_review!('source_unverified') if provider_review_required?(provider_response)

    block_reason = final_block_reason
    return block_intent!(block_reason) if block_reason.present?

    outbound_message = create_outbound_message!(provider_response, answer_result.sources)
    create_outbox_event!(outbound_message)
    completed_intent = complete_intent!(outbound_message, provider_response, answer_result.sources)
    @outbound_message_delivery_id = outbound_message.id
    completed_intent
  end

  def enqueue_outbound_message_delivery
    return if @outbound_message_delivery_id.blank?

    SendReplyJob.perform_later(@outbound_message_delivery_id)
  end

  def build_provider_answer(answer_result)
    ai_provider_client.complete(
      messages: provider_messages(answer_result),
      max_tokens: 320,
      temperature: 0.1
    )
  end

  def ai_provider_client
    @ai_provider_client ||= AiLeadEmployee::AiProvider::ClientFactory.for(account: account)
  end

  def provider_messages(answer_result)
    [
      { role: 'system', content: PROVIDER_SYSTEM_PROMPT },
      { role: 'user', content: "Lead question: #{triggering_message.content}\nApproved source answer: #{answer_result.answer}" }
    ]
  end

  def provider_review_required?(provider_response)
    provider_response.content.to_s.strip == 'REVIEW_REQUIRED'
  end

  def create_outbound_message!(provider_response, source_references)
    conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: provider_response.content,
      private: false,
      additional_attributes: {
        ai_lead_employee: {
          orchestration_intent_id: intent.id,
          actor_type: AiLeadEmployee::Orchestration::DecisionPlaceholder::ACTOR_TYPE,
          delivery_boundary: AiLeadEmployee::Orchestration::DecisionPlaceholder::DELIVERY_BOUNDARY,
          outbound_intent_status: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOUND_INTENT_STATUS,
          source_references: source_references
        }
      }
    )
  end

  def create_outbox_event!(outbound_message)
    OutboxEvent.create!(
      account: account,
      aggregate: outbound_message,
      event_type: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOX_EVENT_TYPE,
      idempotency_key: "ai-outbound/#{intent.id}",
      payload: {
        message_id: outbound_message.id,
        conversation_id: conversation.id,
        triggering_message_id: triggering_message.id,
        orchestration_intent_id: intent.id,
        channel: 'whatsapp'
      }
    )
  end

  def complete_intent!(outbound_message, provider_response, source_references)
    connection = account.ai_provider_connection
    intent.update!(
      state: :completed,
      outbound_message: outbound_message,
      source_references: source_references,
      selected_provider: connection&.provider,
      model: provider_response.model || connection&.model,
      decision: {
        status: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOUND_INTENT_STATUS,
        triggering_message_id: triggering_message.id,
        outbound_message_id: outbound_message.id,
        provider_response_id: provider_response.id
      },
      completed_at: Time.current
    )
    intent
  end

  def request_review!(reason)
    review_result = AiLeadEmployee::HumanReviewRequestService.new(
      conversation: conversation,
      lead_message: triggering_message,
      reason: reason.to_s
    ).perform
    block_intent!(BLOCK_REASONS.fetch(reason.to_sym, reason.to_s), review_request: review_result.request)
  end

  def block_intent!(reason, review_request: nil)
    intent.update!(state: :blocked, blocked_reason: reason, blocked_at: Time.current, review_request: review_request)
    intent
  end
end
