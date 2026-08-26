# frozen_string_literal: true

# == Schema Information
#
# Table name: lead_follow_ups
#
#  id                        :bigint           not null, primary key
#  attempt_number            :integer          not null
#  cancellation_reason       :string
#  cancelled_at              :datetime
#  content                   :text
#  control_version           :integer          not null
#  failed_at                 :datetime
#  failure_reason            :string
#  question_text             :text             not null
#  scheduled_at              :datetime         not null
#  sent_at                   :datetime
#  stage                     :integer          not null
#  status                    :integer          default("pending"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  contact_id                :bigint           not null
#  conversation_id           :bigint           not null
#  lead_qualification_id     :bigint           not null
#  message_id                :bigint
#  qualification_question_id :bigint
#
# Indexes
#
#  idx_lead_follow_ups_on_logical_attempt               (account_id,contact_id,stage,attempt_number) UNIQUE
#  idx_on_account_id_conversation_id_status_0550f295fb  (account_id,conversation_id,status)
#  index_lead_follow_ups_on_account_id                  (account_id)
#  index_lead_follow_ups_on_contact_id                  (contact_id)
#  index_lead_follow_ups_on_conversation_id             (conversation_id)
#  index_lead_follow_ups_on_lead_qualification_id       (lead_qualification_id)
#  index_lead_follow_ups_on_message_id                  (message_id)
#  index_lead_follow_ups_on_qualification_question_id   (qualification_question_id)
#  index_lead_follow_ups_on_status_and_scheduled_at     (status,scheduled_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (lead_qualification_id => lead_qualifications.id)
#  fk_rails_...  (message_id => messages.id)
#  fk_rails_...  (qualification_question_id => qualification_questions.id)
#
class LeadFollowUp < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :conversation
  belongs_to :lead_qualification
  belongs_to :qualification_question, optional: true
  belongs_to :message, optional: true

  enum status: {
    pending: 0,
    sent: 1,
    cancelled: 2,
    failed: 3
  }
  enum stage: {
    incomplete_qualification: 0,
    qualified_nurture: 1
  }

  validates :attempt_number, :stage, :status, :question_text, :control_version, :scheduled_at, presence: true
  validates :attempt_number, uniqueness: { scope: [:account_id, :contact_id, :stage] }
  validate :validate_account_scope

  scope :pending_for_conversation, ->(conversation) { pending.where(account: conversation.account, conversation: conversation) }

  def cancel!(reason)
    return unless pending?

    update!(status: :cancelled, cancellation_reason: reason, cancelled_at: Time.current)
  end

  private

  def validate_account_scope
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
    return if lead_qualification.blank?

    errors.add(:lead_qualification, 'must belong to the same account') if lead_qualification.account_id != account_id
  end
end
