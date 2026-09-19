# frozen_string_literal: true

class ReviewConfigurationSuggestion < ApplicationRecord
  belongs_to :account
  belongs_to :human_review_request, optional: true
  belongs_to :lead_handoff, optional: true
  belongs_to :conversation
  belongs_to :offer, class_name: 'AiLeadEmployee::Offer', optional: true
  belongs_to :source_message, class_name: 'Message', optional: true
  belongs_to :proposed_by_user, class_name: 'User'
  belongs_to :reviewed_by_user, class_name: 'User', optional: true

  enum category: { poor_fit: 0, not_ready: 1 }
  enum status: { pending: 0, reviewed: 1, dismissed: 2 }

  validates :category, :status, :suggestion, :evidence, presence: true
  validate :exactly_one_source
  validate :tenant_scope
  validate :user_scope
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

    validate_association_account(:human_review_request, human_review_request) if human_review_request
    validate_association_account(:lead_handoff, lead_handoff) if lead_handoff
    validate_association_account(:conversation, conversation)
    validate_association_account(:offer, offer) if offer
    validate_association_account(:source_message, source_message) if source_message
  end

  def evidence_scope
    source_conversation_id = human_review_request&.conversation_id || lead_handoff&.conversation_id
    errors.add(:conversation, 'must match the feedback source') if source_conversation_id != conversation_id
    validate_source_offer
    validate_source_message
  end

  def user_scope
    validate_account_user(:proposed_by_user, proposed_by_user) if proposed_by_membership_changed?
    validate_account_user(:reviewed_by_user, reviewed_by_user) if reviewed_by_user_membership_changed?
  end

  def validate_source_offer
    return unless source_provenance_changed?

    errors.add(:offer, 'must match the feedback source') if offer_id != source_offer_id
  end

  def source_offer_id
    return human_review_request.conversation.offer_id if human_review_request

    lead_handoff&.lead_qualification&.offer_id
  end

  def validate_source_message
    return unless source_provenance_changed?

    if human_review_request
      errors.add(:source_message, 'must be the Review source message') if source_message_id != human_review_request.lead_message_id
    elsif source_message
      errors.add(:source_message, 'is not permitted for a Lead Handoff')
    end
    return if source_message.blank?

    errors.add(:source_message, 'must belong to the feedback conversation') if source_message.conversation_id != conversation_id
  end

  def exactly_one_source
    sources = [human_review_request, lead_handoff].compact
    errors.add(:base, 'must belong to exactly one feedback source') unless sources.one?
  end

  def validate_association_account(name, record)
    errors.add(name, 'must belong to the same Business Account') if record&.account_id != account_id
  end

  def validate_account_user(name, user)
    return if AccountUser.exists?(account_id: account_id, user_id: user&.id)

    errors.add(name, 'must belong to the same Business Account')
  end

  def source_provenance_changed?
    new_record? || will_save_change_to_human_review_request_id? || will_save_change_to_lead_handoff_id? ||
      will_save_change_to_offer_id? || will_save_change_to_source_message_id?
  end

  def proposed_by_membership_changed?
    new_record? || will_save_change_to_account_id? || will_save_change_to_proposed_by_user_id?
  end

  def reviewed_by_user_membership_changed?
    reviewed_by_user.present? &&
      (new_record? || will_save_change_to_account_id? || will_save_change_to_reviewed_by_user_id?)
  end
end
