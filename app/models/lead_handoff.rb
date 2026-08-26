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

  enum status: {
    open: 0,
    completed: 1,
    canceled: 2
  }

  validates :alert_type, :status, :qualification_snapshot, :handed_off_at, presence: true
  validates :conversation_id, uniqueness: { scope: [:account_id, :lead_qualification_id, :alert_type] }
  validate :records_belong_to_account

  private

  def records_belong_to_account
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
    return unless lead_qualification.present? && lead_qualification.account_id != account_id

    errors.add(:lead_qualification, 'must belong to the same account')
  end
end
