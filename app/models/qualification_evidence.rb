# frozen_string_literal: true

# == Schema Information
#
# Table name: qualification_evidences
#
#  id               :bigint           not null, primary key
#  observed_at      :datetime         not null
#  signal           :integer          not null
#  source           :integer          not null
#  superseded_at    :datetime
#  value            :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  contact_id       :bigint           not null
#  conversation_id  :bigint
#  message_id       :bigint
#  superseded_by_id :bigint
#  user_id          :bigint
#
# Indexes
#
#  idx_qualification_evidence_current_lookup          (account_id,contact_id,signal,superseded_at)
#  index_qualification_evidences_on_account_id        (account_id)
#  index_qualification_evidences_on_contact_id        (contact_id)
#  index_qualification_evidences_on_conversation_id   (conversation_id)
#  index_qualification_evidences_on_message_id        (message_id)
#  index_qualification_evidences_on_superseded_by_id  (superseded_by_id)
#  index_qualification_evidences_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (message_id => messages.id)
#  fk_rails_...  (superseded_by_id => qualification_evidences.id)
#  fk_rails_...  (user_id => users.id)
#
class QualificationEvidence < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true
  belongs_to :user, optional: true
  belongs_to :superseded_by, class_name: 'QualificationEvidence', optional: true

  enum signal: QualificationQuestion::SIGNALS
  enum source: { extracted: 0, human: 1 }

  validates :signal, :source, :observed_at, presence: true
  validate :validate_account_scope

  scope :current, -> { where(superseded_at: nil) }

  private

  def validate_account_scope
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
    errors.add(:message, 'must belong to the same account') if message.present? && message.account_id != account_id
  end
end
