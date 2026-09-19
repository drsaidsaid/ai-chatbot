# frozen_string_literal: true

class ReviewConfigurationSuggestion < ApplicationRecord
  belongs_to :account
  belongs_to :human_review_request
  belongs_to :conversation
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer', optional: true
  belongs_to :source_message, class_name: 'Message'
  belongs_to :proposed_by_user, class_name: 'User'
  belongs_to :reviewed_by_user, class_name: 'User', optional: true

  enum category: { poor_fit: 0, not_ready: 1 }
  enum status: { pending: 0, reviewed: 1, dismissed: 2 }

  validates :category, :status, :suggestion, :evidence, presence: true
  validate :tenant_scope
  validate :evidence_scope

  def review!(reviewer:, outcome:, decision_note: nil)
    transaction do
      lock!
      membership = AccountUser.where(account_id: account_id, user_id: reviewer&.id).lock.first
      raise Pundit::NotAuthorizedError unless membership&.administrator?
      raise ArgumentError, 'unsupported review outcome' unless %w[reviewed dismissed].include?(outcome)

      update!(status: outcome, reviewed_by_user: reviewer, reviewed_at: Time.current, decision_note: decision_note)
    end
    self
  end

  private

  def tenant_scope
    return if account_id.blank?

    validate_association_account(:human_review_request, human_review_request)
    validate_association_account(:conversation, conversation)
    validate_association_account(:offer, offer) if offer
    validate_association_account(:source_message, source_message)
  end

  def evidence_scope
    errors.add(:conversation, 'must match the Review Request') if human_review_request&.conversation_id != conversation_id
    errors.add(:source_message, 'must belong to the Review conversation') if source_message&.conversation_id != conversation_id
  end

  def validate_association_account(name, record)
    errors.add(name, 'must belong to the same Business Account') if record&.account_id != account_id
  end
end
