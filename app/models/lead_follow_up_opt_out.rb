# frozen_string_literal: true

# == Schema Information
#
# Table name: lead_follow_up_opt_outs
#
#  id              :bigint           not null, primary key
#  opted_out_at    :datetime         not null
#  reason          :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  contact_id      :bigint           not null
#  conversation_id :bigint
#  message_id      :bigint
#
# Indexes
#
#  index_lead_follow_up_opt_outs_on_account_id                 (account_id)
#  index_lead_follow_up_opt_outs_on_account_id_and_contact_id  (account_id,contact_id) UNIQUE
#  index_lead_follow_up_opt_outs_on_contact_id                 (contact_id)
#  index_lead_follow_up_opt_outs_on_conversation_id            (conversation_id)
#  index_lead_follow_up_opt_outs_on_message_id                 (message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (message_id => messages.id)
#
class LeadFollowUpOptOut < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :conversation, optional: true
  belongs_to :message, optional: true

  validates :reason, :opted_out_at, presence: true
  validates :contact_id, uniqueness: { scope: :account_id }
  validate :validate_account_scope

  private

  def validate_account_scope
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
  end
end
