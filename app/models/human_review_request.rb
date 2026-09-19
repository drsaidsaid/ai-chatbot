# frozen_string_literal: true

# == Schema Information
#
# Table name: human_review_requests
#
#  id                      :bigint           not null, primary key
#  alert_deliveries        :jsonb            not null
#  alert_recipients        :jsonb            not null
#  operator_answer         :text
#  proposed_source_kind    :string
#  question                :text             not null
#  reason                  :integer          default("no_approved_knowledge"), not null
#  rejected_at             :datetime
#  resolution_kind         :string
#  resolved_at             :datetime
#  status                  :integer          default("open"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  assigned_user_id        :bigint
#  conversation_id         :bigint           not null
#  human_answer_message_id :bigint
#  knowledge_item_id       :bigint
#  lead_message_id         :bigint           not null
#
# Indexes
#
#  idx_on_account_id_status_created_at_2f522df2ef          (account_id,status,created_at)
#  index_human_review_requests_on_account_id               (account_id)
#  index_human_review_requests_on_assigned_user_id         (assigned_user_id)
#  index_human_review_requests_on_conversation_id          (conversation_id)
#  index_human_review_requests_on_deduplication_key        (account_id,conversation_id,lead_message_id,reason) UNIQUE
#  index_human_review_requests_on_human_answer_message_id  (human_answer_message_id)
#  index_human_review_requests_on_knowledge_item_id        (knowledge_item_id)
#  index_human_review_requests_on_lead_message_id          (lead_message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assigned_user_id => users.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (human_answer_message_id => messages.id)
#  fk_rails_...  (knowledge_item_id => knowledge_items.id)
#  fk_rails_...  (lead_message_id => messages.id)
#
class HumanReviewRequest < ApplicationRecord # rubocop:disable Metrics/ClassLength
  belongs_to :account
  belongs_to :conversation
  belongs_to :lead_message, class_name: 'Message'
  belongs_to :human_answer_message, class_name: 'Message', optional: true
  belongs_to :knowledge_item, optional: true
  belongs_to :assigned_user, class_name: 'User', optional: true
  has_one :configuration_suggestion, class_name: 'ReviewConfigurationSuggestion', dependent: :restrict_with_exception

  enum reason: {
    no_approved_knowledge: 0,
    conflicting_knowledge: 1,
    sensitive_question: 2,
    qualification_blocker: 3,
    angry_question: 4,
    unsupported_media: 5,
    source_unverified: 6,
    provider_failed: 7,
    stale_knowledge: 8,
    delivery_unknown: 9,
    human_requested: 10
  }
  enum status: {
    open: 0,
    resolved: 1,
    rejected: 2
  }

  validates :question, :reason, :status, presence: true
  validates :lead_message_id, uniqueness: { scope: [:account_id, :conversation_id, :reason] }
  validate :messages_belong_to_conversation
  validate :knowledge_item_belongs_to_account

  scope :operator_queue, -> { open.order(created_at: :asc) }

  def assign_to!(user)
    transaction do
      Conversation.where(account_id: account_id, id: conversation_id).lock('FOR NO KEY UPDATE').first!
      with_lock do
        previous_assignee_id = assigned_user_id
        return self if previous_assignee_id == user&.id

        Conversations::AssignmentService.new(conversation: conversation, assignee_id: user&.id).perform
        update!(assigned_user: user)
        audit_assignment!(previous_assignee_id)
      end
    end
    self
  end

  def reject!(operator_answer:)
    update!(status: :rejected, operator_answer: operator_answer, resolution_kind: 'rejected', rejected_at: Time.current)
  end

  def resolve_with!(answer:, operator:, resolution_kind:, existing_message: nil)
    with_authorized_review_lock(operator) do |locked_conversation|
      return self if resolved?

      message = resolution_message(
        answer: answer,
        operator: operator,
        resolution_kind: resolution_kind,
        existing_message: existing_message,
        locked_conversation: locked_conversation
      )
      validate_human_answer!(message)

      update!(
        human_answer_message: message,
        operator_answer: message.content,
        resolution_kind: resolution_kind,
        status: :resolved,
        resolved_at: Time.current
      )
    end
    self
  end

  def propose_knowledge!(proposer:, source_kind:, title:, answer: nil)
    with_authorized_review_lock(proposer, lock_knowledge_authority: true) do |locked_conversation|
      return knowledge_item if knowledge_item.present?

      unless resolved? && human_answer_message.present?
        errors.add(:base, 'must be resolved before reusable knowledge can be proposed')
        raise ActiveRecord::RecordInvalid, self
      end

      item = account.knowledge_items.create!(
        title: title.presence || question.truncate(80),
        question: question,
        answer: proposal_answer(answer),
        source_kind: source_kind,
        status: :draft,
        metadata: proposal_metadata(proposer, locked_conversation)
      )
      update!(knowledge_item: item, proposed_source_kind: item.source_kind)
      item
    end
  end

  def propose_configuration_suggestion!(proposer:, category:, suggestion:)
    with_authorized_review_lock(proposer) do |locked_conversation|
      return configuration_suggestion if configuration_suggestion.present?

      unless resolved?
        errors.add(:base, 'must be resolved before handoff feedback can be proposed')
        raise ActiveRecord::RecordInvalid, self
      end

      create_configuration_suggestion!(
        account: account,
        conversation: locked_conversation,
        offer: locked_conversation.offer,
        source_message: lead_message,
        proposed_by_user: proposer,
        category: category,
        suggestion: suggestion,
        evidence: question,
        status: :pending
      )
    end
  end

  private

  def audit_assignment!(previous_assignee_id)
    Audited::Audit.create!(
      auditable: self,
      associated: account,
      user: Current.user,
      action: 'update',
      audited_changes: {
        'ai_lead_employee_action' => 'human_review_assignment',
        'assigned_user_id' => [previous_assignee_id, assigned_user_id]
      },
      version: Audited::Audit.where(auditable: self).maximum(:version).to_i + 1,
      created_at: Time.current
    )
  end

  def resolution_message(answer:, operator:, resolution_kind:, existing_message:, locked_conversation:)
    return existing_message if existing_message

    locked_conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      sender: operator,
      message_type: :outgoing,
      private: resolution_kind == 'internal_note',
      content: answer
    )
  end

  def with_authorized_review_lock(actor, lock_knowledge_authority: false)
    ApplicationRecord.transaction do
      if lock_knowledge_authority
        AiLeadEmployee::KnowledgeAuthorityLock.acquire_for_answer!(account_id)
      else
        Account.where(id: account_id).lock('FOR KEY SHARE').load
      end
      locked_conversation = Conversation.where(account_id: account_id, id: conversation_id)
                                        .lock('FOR NO KEY UPDATE').first!
      self.class.where(account_id: account_id, id: id).lock.first!
      reload
      authorize_mutation!(actor, locked_conversation)
      yield locked_conversation
    end
  end

  def authorize_mutation!(actor, locked_conversation)
    membership = AccountUser.where(account_id: account_id, user_id: actor&.id).lock.first
    return if membership&.administrator?
    return if membership.present? && locked_conversation.assignee_id == actor.id

    raise Pundit::NotAuthorizedError
  end

  def validate_human_answer!(human_answer_message)
    return if human_answer_message.sender.is_a?(User)

    errors.add(:human_answer_message, 'must be sent by a Human Operator')
    raise ActiveRecord::RecordInvalid, self
  end

  def proposal_metadata(proposer, locked_conversation)
    {
      proposed_from_human_review_request_id: id,
      proposed_by_user_id: proposer&.id,
      source_message_id: proposal_source_message_id,
      source_conversation_id: conversation_id,
      offer_ids: locked_conversation.offer_id ? [locked_conversation.offer_id] : []
    }.compact
  end

  def proposal_source_message_id
    human_answer_message_id unless human_answer_message.private?
  end

  def proposal_answer(answer)
    return answer if answer.present?
    return human_answer_message.content unless human_answer_message.private?

    errors.add(:base, 'requires a separate reusable answer when the resolution is private')
    raise ActiveRecord::RecordInvalid, self
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
