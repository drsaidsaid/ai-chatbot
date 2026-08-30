# frozen_string_literal: true

# == Schema Information
#
# Table name: human_review_requests
#
#  id                      :bigint           not null, primary key
#  alert_deliveries        :jsonb            not null
#  alert_recipients        :jsonb            not null
#  proposed_source_kind    :string
#  question                :text             not null
#  reason                  :integer          not null
#  resolved_at             :datetime
#  status                  :integer          default("open"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  conversation_id         :bigint           not null
#  human_answer_message_id :bigint
#  knowledge_item_id       :bigint
#  lead_message_id         :bigint           not null
#
# Indexes
#
#  idx_on_account_id_status_created_at_2f522df2ef          (account_id,status,created_at)
#  index_human_review_requests_on_account_id               (account_id)
#  index_human_review_requests_on_conversation_id          (conversation_id)
#  index_human_review_requests_on_deduplication_key        (account_id,conversation_id,lead_message_id,reason) UNIQUE
#  index_human_review_requests_on_human_answer_message_id  (human_answer_message_id)
#  index_human_review_requests_on_knowledge_item_id        (knowledge_item_id)
#  index_human_review_requests_on_lead_message_id          (lead_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (human_answer_message_id => messages.id)
#  fk_rails_...  (knowledge_item_id => knowledge_items.id)
#  fk_rails_...  (lead_message_id => messages.id)
#
class HumanReviewRequest < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :lead_message, class_name: 'Message'
  belongs_to :human_answer_message, class_name: 'Message', optional: true
  belongs_to :knowledge_item, optional: true

  enum reason: {
    no_approved_knowledge: 0,
    conflicting_knowledge: 1,
    sensitive_question: 2,
    qualification_blocker: 3,
    angry_question: 4,
    unsupported_media: 5,
    source_unverified: 6,
    provider_failed: 7,
    stale_knowledge: 8
  }
  enum status: {
    open: 0,
    resolved: 1
  }

  validates :question, :reason, :status, presence: true
  validates :lead_message_id, uniqueness: { scope: [:account_id, :conversation_id, :reason] }
  validate :messages_belong_to_conversation
  validate :knowledge_item_belongs_to_account

  scope :operator_queue, -> { open.order(created_at: :asc) }

  def resolve!(human_answer_message:, proposer:, propose_knowledge:, source_kind:, title:)
    validate_human_answer!(human_answer_message)

    transaction do
      item = nil
      if ActiveModel::Type::Boolean.new.cast(propose_knowledge)
        item = propose_knowledge_item(
          proposer: proposer,
          source_kind: source_kind,
          title: title,
          answer: human_answer_message.content
        )
      end

      update!(
        human_answer_message: human_answer_message,
        knowledge_item: item,
        proposed_source_kind: item&.source_kind || source_kind,
        status: :resolved,
        resolved_at: Time.current
      )
    end
  end

  private

  def validate_human_answer!(human_answer_message)
    return if human_answer_message.sender.is_a?(User)

    errors.add(:human_answer_message, 'must be sent by a Human Operator')
    raise ActiveRecord::RecordInvalid, self
  end

  def propose_knowledge_item(proposer:, source_kind:, title:, answer:)
    account.knowledge_items.create!(
      title: title.presence || question.truncate(80),
      question: question,
      answer: answer,
      source_kind: source_kind,
      status: :draft,
      metadata: {
        proposed_from_human_review_request_id: id,
        proposed_by_user_id: proposer&.id
      }.compact
    )
  end

  def messages_belong_to_conversation
    return if conversation.blank?

    errors.add(:lead_message, 'must belong to the review conversation') if lead_message.present? && lead_message.conversation_id != conversation_id

    return unless human_answer_message.present? && human_answer_message.conversation_id != conversation_id

    errors.add(:human_answer_message, 'must belong to the review conversation')
  end

  def knowledge_item_belongs_to_account
    return if knowledge_item.blank? || knowledge_item.account_id == account_id

    errors.add(:knowledge_item, 'must belong to the review account')
  end
end
