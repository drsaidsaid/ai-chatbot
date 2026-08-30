# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_orchestration_intents
#
class AiLeadEmployee::OrchestrationIntent < ApplicationRecord
  self.table_name = 'ai_orchestration_intents'

  belongs_to :account
  belongs_to :conversation
  belongs_to :triggering_message, class_name: 'Message'
  belongs_to :review_request, class_name: 'HumanReviewRequest', optional: true
  belongs_to :outbound_message, class_name: 'Message', optional: true

  enum :state, { pending: 0, processing: 1, completed: 2, blocked: 3, failed: 4 }

  validates :idempotency_key, :observed_control_version, presence: true
  validates :idempotency_key, uniqueness: { scope: :account_id }
  validate :validate_account_scope

  def terminal?
    completed? || blocked? || failed?
  end

  private

  def validate_account_scope
    return if blocked_reason == AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS[:tenant_scope_mismatch]

    validate_conversation_scope
    validate_triggering_message_scope
    validate_outbound_message_scope
  end

  def validate_conversation_scope
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
  end

  def validate_triggering_message_scope
    errors.add(:triggering_message, 'must belong to the same account') if triggering_message.present? && triggering_message.account_id != account_id
  end

  def validate_outbound_message_scope
    errors.add(:outbound_message, 'must belong to the same account') if outbound_message.present? && outbound_message.account_id != account_id
  end
end
