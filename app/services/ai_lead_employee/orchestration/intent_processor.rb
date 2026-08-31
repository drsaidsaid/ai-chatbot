# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class AiLeadEmployee::Orchestration::IntentProcessor
  PROVIDER_SYSTEM_PROMPT = [
    'Answer the lead only from the approved business source supplied.',
    'Do not add facts, pricing, guarantees, or policies not present in the source.',
    'If the source is insufficient, respond with exactly: REVIEW_REQUIRED.'
  ].join(' ')
  BLOCK_REASONS = AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS

  FINAL_CHECKS = [
    [:tenant_scope_mismatch, :tenant_scope_mismatch?],
    [:launch_gate_not_approved, :launch_gate_not_approved?],
    [:stale_control_version, :stale_control_version?],
    [:incompatible_control_state, :incompatible_control_state?],
    [:ineligible_inbox_status, :ineligible_inbox_status?],
    [:assigned_to_human_operator, :assigned_to_human_operator?],
    [:opted_out, :opted_out?],
    [:human_reply_after_trigger, :human_reply_after_trigger?]
  ].freeze

  def initialize(intent:, enqueue_deliveries: true, enforce_launch_gate: true)
    @intent = intent
    @enqueue_deliveries = enqueue_deliveries
    @enforce_launch_gate = enforce_launch_gate
  end

  # rubocop:disable Metrics/MethodLength
  def perform
    @outbound_message_delivery_id = nil
    @handoff_alert_delivery_ids = []
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
    enqueue_handoff_alert_deliveries
    processed_intent
  rescue AiLeadEmployee::AiProvider::ProviderFailure => e
    AiLeadEmployee::Orchestration::ProviderFailureHandler.new(
      intent: intent,
      failure: e,
      enqueue_review_alerts: enqueue_deliveries
    ).perform
  end
  # rubocop:enable Metrics/MethodLength

  private

  attr_reader :intent, :enqueue_deliveries, :enforce_launch_gate

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

  def launch_gate_not_approved?
    enforce_launch_gate && !AiLeadEmployee::LaunchGate.live_ai_enabled?(account)
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
    qualification_result = qualify_lead!
    qualification_result_response = qualification_result_response(qualification_result)
    return qualification_result_response if qualification_result_response.present?

    answer_result = AiLeadEmployee::KnowledgeAnswerService.new(account: account, question: triggering_message.content).perform
    return request_review!(answer_result.refusal_reason) if answer_result.refused?

    provider_response = build_provider_answer(answer_result)
    return request_review!('source_unverified') if provider_review_required?(provider_response)

    block_reason = final_block_reason
    return block_intent!(block_reason) if block_reason.present?

    complete_grounded_answer!(provider_response, answer_result, qualification_result)
  end

  def qualification_result_response(qualification_result)
    handoff_result = create_highly_qualified_handoff(qualification_result)
    return complete_handoff!(handoff_result, qualification_result) if handoff_result&.handoff.present?
    return complete_unsupported_human_request!(qualification_result) if unsupported_human_request?(qualification_result)
  end

  def complete_grounded_answer!(provider_response, answer_result, qualification_result)
    outbound_message = create_outbound_message!(
      content: reply_content(provider_response.content, qualification_result),
      source_references: answer_result.sources,
      qualification_result: qualification_result,
      status: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOUND_INTENT_STATUS
    )
    create_outbox_event!(outbound_message)
    completed_intent = complete_intent!(
      outbound_message: outbound_message,
      provider_response: provider_response,
      source_references: answer_result.sources,
      qualification_result: qualification_result,
      status: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOUND_INTENT_STATUS
    )
    @outbound_message_delivery_id = outbound_message.id
    completed_intent
  end

  def qualify_lead!
    AiLeadEmployee::QualificationService.new(
      conversation: conversation,
      incoming_message: triggering_message
    ).perform
  end

  def create_highly_qualified_handoff(qualification_result)
    AiLeadEmployee::HighlyQualifiedHandoffService.new(
      conversation: conversation,
      qualification: qualification_result.qualification,
      defer_alert_delivery: true
    ).perform
  end

  def complete_handoff!(handoff_result, qualification_result)
    @handoff_alert_delivery_ids = handoff_result.alert_message_ids
    intent.update!(
      state: :completed,
      source_references: qualification_source_references(qualification_result),
      decision: {
        status: 'highly_qualified_handoff',
        triggering_message_id: triggering_message.id,
        handoff_id: handoff_result.handoff.id,
        qualification: qualification_result_payload(qualification_result)
      },
      completed_at: Time.current
    )
    record_ai_employee_decision!(status: 'highly_qualified_handoff', qualification_result: qualification_result)
    intent
  end

  def complete_unsupported_human_request!(qualification_result)
    outbound_message = create_outbound_message!(
      content: human_request_explanation(qualification_result),
      source_references: qualification_source_references(qualification_result),
      qualification_result: qualification_result,
      status: 'qualification_question'
    )
    create_outbox_event!(outbound_message)
    complete_intent!(
      outbound_message: outbound_message,
      provider_response: nil,
      source_references: qualification_source_references(qualification_result),
      qualification_result: qualification_result,
      status: 'qualification_question'
    )
    @outbound_message_delivery_id = outbound_message.id
    intent
  end

  def enqueue_outbound_message_delivery
    return if @outbound_message_delivery_id.blank?
    return unless enqueue_deliveries

    SendReplyJob.perform_later(@outbound_message_delivery_id)
  end

  def enqueue_handoff_alert_deliveries
    return unless enqueue_deliveries

    @handoff_alert_delivery_ids.each { |message_id| SendReplyJob.perform_later(message_id) }
  end

  def build_provider_answer(answer_result)
    ai_provider_client.complete(
      messages: provider_messages(answer_result),
      max_tokens: 64,
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

  def create_outbound_message!(content:, source_references:, qualification_result:, status:)
    conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: content,
      private: false,
      additional_attributes: {
        ai_lead_employee: {
          orchestration_intent_id: intent.id,
          actor_type: AiLeadEmployee::Orchestration::DecisionPlaceholder::ACTOR_TYPE,
          delivery_boundary: AiLeadEmployee::Orchestration::DecisionPlaceholder::DELIVERY_BOUNDARY,
          outbound_intent_status: status,
          source_references: source_references,
          qualification: qualification_result_payload(qualification_result)
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

  def complete_intent!(outbound_message:, provider_response:, source_references:, qualification_result:, status:)
    intent.update!(completion_attributes(outbound_message, provider_response, source_references, qualification_result, status))
    record_ai_employee_decision!(
      status: status,
      qualification_result: qualification_result,
      source_references: source_references
    )
    intent
  end

  def completion_attributes(outbound_message, provider_response, source_references, qualification_result, status)
    connection = account.ai_provider_connection
    {
      state: :completed,
      outbound_message: outbound_message,
      source_references: source_references,
      selected_provider: connection&.provider,
      model: provider_response&.model || connection&.model,
      decision: {
        status: status,
        triggering_message_id: triggering_message.id,
        outbound_message_id: outbound_message.id,
        provider_response_id: provider_response&.id,
        qualification: qualification_result_payload(qualification_result)
      },
      completed_at: Time.current
    }
  end

  def reply_content(answer_content, qualification_result)
    return answer_content if qualification_result&.next_question.blank?

    [answer_content, qualification_result.next_question].join("\n\n")
  end

  def unsupported_human_request?(qualification_result)
    qualification_result.present? &&
      qualification_result.qualification&.highly_qualified? == false &&
      triggering_message.content.to_s.match?(/\b(human|person|operator|agent|sales|representative)\b/i)
  end

  def human_request_explanation(qualification_result)
    [
      AiLeadEmployee::HighlyQualifiedHandoffService.unqualified_human_request_explanation(account),
      qualification_result.next_question
    ].compact_blank.join("\n\n")
  end

  def qualification_source_references(qualification_result)
    qualification_result.qualification.evidence_snapshot.values.filter_map { |evidence| evidence['source_reference'] }
  end

  def qualification_result_payload(qualification_result)
    return nil if qualification_result.blank?

    {
      'quality' => qualification_result.qualification.quality,
      'score' => qualification_result.qualification.score,
      'missing_signals' => qualification_result.qualification.missing_signals,
      'next_question' => qualification_result.next_question,
      'configuration_version' => qualification_result.qualification.configuration_version
    }
  end

  def record_ai_employee_decision!(status:, qualification_result:, source_references: [])
    conversation.update!(
      additional_attributes: conversation.additional_attributes.merge(
        'ai_employee_last_decision' => {
          'status' => status,
          'sources' => source_references,
          'qualification' => qualification_result_payload(qualification_result)
        }
      )
    )
  end

  def request_review!(reason)
    review_result = AiLeadEmployee::HumanReviewRequestService.new(
      conversation: conversation,
      lead_message: triggering_message,
      reason: reason.to_s,
      enqueue_alerts: enqueue_deliveries
    ).perform
    block_intent!(BLOCK_REASONS.fetch(reason.to_sym, reason.to_s), review_request: review_result.request)
  end

  def block_intent!(reason, review_request: nil)
    intent.update!(state: :blocked, blocked_reason: reason, blocked_at: Time.current, review_request: review_request)
    intent
  end
end
# rubocop:enable Metrics/ClassLength
