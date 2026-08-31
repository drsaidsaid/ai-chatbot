# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_orchestration_intents
#
#  id                       :bigint           not null, primary key
#  attempts                 :integer          default(0), not null
#  blocked_at               :datetime
#  blocked_reason           :string
#  completed_at             :datetime
#  decision                 :jsonb            not null
#  failure_class            :string
#  idempotency_key          :string           not null
#  model                    :string
#  observed_control_version :integer          not null
#  selected_provider        :string
#  source_references        :jsonb            not null
#  state                    :integer          default("pending"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  conversation_id          :bigint           not null
#  outbound_message_id      :bigint
#  review_request_id        :bigint
#  triggering_message_id    :bigint           not null
#
# Indexes
#
#  idx_ai_orchestration_intents_on_logical_trigger          (account_id,conversation_id,triggering_message_id,observed_control_version) UNIQUE
#  idx_on_account_id_conversation_id_state_b83b69ea47       (account_id,conversation_id,state)
#  idx_on_account_id_idempotency_key_c7b0a1d67b             (account_id,idempotency_key) UNIQUE
#  index_ai_orchestration_intents_on_account_id             (account_id)
#  index_ai_orchestration_intents_on_conversation_id        (conversation_id)
#  index_ai_orchestration_intents_on_outbound_message_id    (outbound_message_id)
#  index_ai_orchestration_intents_on_review_request_id      (review_request_id)
#  index_ai_orchestration_intents_on_triggering_message_id  (triggering_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (outbound_message_id => messages.id)
#  fk_rails_...  (review_request_id => human_review_requests.id)
#  fk_rails_...  (triggering_message_id => messages.id)
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
