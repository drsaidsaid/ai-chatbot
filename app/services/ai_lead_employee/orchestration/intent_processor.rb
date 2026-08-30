# frozen_string_literal: true

class AiLeadEmployee::Orchestration::IntentProcessor
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
    ActiveRecord::Base.transaction do
      intent.lock!
      return intent if intent.terminal?

      conversation.lock!
      intent.attempts += 1

      block_reason = final_block_reason
      return block_intent!(block_reason) if block_reason.present?

      outbound_message = create_outbound_message!
      create_outbox_event!(outbound_message)
      complete_intent!(outbound_message)
    end
  rescue AiLeadEmployee::AiProvider::ProviderFailure => e
    AiLeadEmployee::Orchestration::ProviderFailureHandler.new(intent: intent, failure: e).perform
  end

  private

  attr_reader :intent

  delegate :conversation, :triggering_message, :account, to: :intent

  def final_block_reason
    reason, = FINAL_CHECKS.find { |(_, predicate)| send(predicate) }
    block_reasons[reason]
  end

  def block_reasons
    AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS
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

  def create_outbound_message!
    conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: nil,
      private: true,
      additional_attributes: {
        ai_lead_employee: {
          orchestration_intent_id: intent.id,
          actor_type: AiLeadEmployee::Orchestration::DecisionPlaceholder::ACTOR_TYPE,
          delivery_boundary: AiLeadEmployee::Orchestration::DecisionPlaceholder::DELIVERY_BOUNDARY,
          outbound_intent_status: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOUND_INTENT_STATUS
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

  def complete_intent!(outbound_message)
    intent.update!(
      state: :completed,
      outbound_message: outbound_message,
      source_references: AiLeadEmployee::Orchestration::DecisionPlaceholder::SOURCE_REFERENCES,
      decision: {
        status: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOUND_INTENT_STATUS,
        triggering_message_id: triggering_message.id,
        outbound_message_id: outbound_message.id
      },
      completed_at: Time.current
    )
    intent
  end

  def block_intent!(reason)
    intent.update!(state: :blocked, blocked_reason: reason, blocked_at: Time.current)
    intent
  end
end
