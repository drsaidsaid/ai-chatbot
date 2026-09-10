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
#  consent_event_id :bigint
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
  belongs_to :consent_event, class_name: 'LeadConsentEvent', optional: true

  validates :reason, :opted_out_at, presence: true
  validates :contact_id, uniqueness: { scope: :account_id }
  validate :contact_account_is_consistent
  validate :conversation_account_is_consistent
  validate :consent_event_is_consistent
  after_create :cancel_pending_automation

  private

  def cancel_pending_automation
    account.conversations.where(contact_id: contact_id).find_each do |item|
      item.with_lock { Conversations::ControlService.invalidate_pending_ai!(conversation: item, reason: 'opted_out') }
    end
  end

  def contact_account_is_consistent
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
  end

  def conversation_account_is_consistent
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
  end

  def consent_event_is_consistent
    return if consent_event.blank? || active_withdrawal_event?

    errors.add(:consent_event, 'must be the active automated-contact withdrawal for this Lead')
  end

  def active_withdrawal_event?
    consent_event.account_id == account_id && consent_event.contact_id == contact_id &&
      consent_event.purpose == 'automated_contact' && consent_event.event_kind == 'withdrawn'
  end
end
