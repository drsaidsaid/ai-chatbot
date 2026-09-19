# frozen_string_literal: true

# == Schema Information
#
# Table name: lead_handoffs
#
#  id                     :bigint           not null, primary key
#  alert_deliveries       :jsonb            not null
#  alert_recipients       :jsonb            not null
#  alert_type             :string           not null
#  handed_off_at          :datetime         not null
#  qualification_snapshot :jsonb            not null
#  status                 :integer          default("open"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  assignee_id            :bigint
#  contact_id             :bigint           not null
#  conversation_id        :bigint           not null
#  lead_qualification_id  :bigint           not null
#
# Indexes
#
#  index_lead_handoffs_on_account_id             (account_id)
#  index_lead_handoffs_on_assignee_id            (assignee_id)
#  index_lead_handoffs_on_contact_id             (contact_id)
#  index_lead_handoffs_on_conversation_id        (conversation_id)
#  index_lead_handoffs_on_lead_qualification_id  (lead_qualification_id)
#  index_lead_handoffs_on_logical_handoff        (account_id,conversation_id,lead_qualification_id,alert_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (lead_qualification_id => lead_qualifications.id)
#
class LeadHandoff < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :conversation
  belongs_to :lead_qualification
  belongs_to :assignee, class_name: 'User', optional: true
  has_one :configuration_suggestion, class_name: 'ReviewConfigurationSuggestion', dependent: :restrict_with_exception

  enum status: {
    open: 0,
    completed: 1,
    canceled: 2
  }

  validates :alert_type, :status, :qualification_snapshot, :handed_off_at, presence: true
  validates :conversation_id, uniqueness: { scope: [:account_id, :lead_qualification_id, :alert_type] }
  validate :records_belong_to_account

  def propose_configuration_suggestion!(proposer:, category:, suggestion:)
    ApplicationRecord.transaction do
      Account.where(id: account_id).lock('FOR KEY SHARE').load
      locked_conversation = Conversation.where(account_id: account_id, id: conversation_id)
                                        .lock('FOR NO KEY UPDATE').first!
      self.class.where(account_id: account_id, id: id).lock.first!
      reload
      authorize_feedback!(proposer, locked_conversation)
      return configuration_suggestion if configuration_suggestion.present?

      create_feedback!(proposer, locked_conversation, category, suggestion)
    end
  end

  private

  def create_feedback!(proposer, locked_conversation, category, suggestion)
    create_configuration_suggestion!(
      account: account,
      conversation: locked_conversation,
      offer: lead_qualification.offer,
      proposed_by_user: proposer,
      category: category,
      suggestion: suggestion,
      evidence: feedback_evidence,
      status: :pending
    )
  end

  def authorize_feedback!(actor, locked_conversation)
    membership = AccountUser.where(account_id: account_id, user_id: actor&.id).lock.first
    return if membership&.administrator?
    return if membership.present? && locked_conversation.assignee_id == actor.id

    raise Pundit::NotAuthorizedError
  end

  def feedback_evidence
    qualification_snapshot.slice('quality', 'score', 'reasons', 'missing_signals', 'assessment', 'evidence').to_json
  end

  def records_belong_to_account
    validate_record_accounts
    validate_record_contacts
  end

  def validate_record_accounts
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
    validate_assignee_account
    return if lead_qualification.blank? || lead_qualification.account_id == account_id

    errors.add(:lead_qualification, 'must belong to the same account')
  end

  def validate_assignee_account
    return unless new_record? || will_save_change_to_account_id? || will_save_change_to_assignee_id?
    return if assignee.blank? || AccountUser.exists?(account_id: account_id, user_id: assignee_id)

    errors.add(:assignee, 'must belong to the same account')
  end

  def validate_record_contacts
    errors.add(:conversation, 'must belong to the same Contact') if conversation&.contact_id != contact_id
    return if lead_qualification.blank? || lead_qualification.contact_id == contact_id

    errors.add(:lead_qualification, 'must belong to the same Contact')
  end
end
