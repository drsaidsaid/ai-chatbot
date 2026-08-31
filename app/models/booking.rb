# frozen_string_literal: true

# == Schema Information
#
# Table name: bookings
#
#  id                           :bigint           not null, primary key
#  calendar_event_payload       :jsonb            not null
#  calendar_invitation_sent_at  :datetime
#  confirmed_at                 :datetime
#  ends_at                      :datetime         not null
#  idempotency_key              :string
#  preparation_alert_deliveries :jsonb            not null
#  preparation_alert_recipients :jsonb            not null
#  provider                     :string           not null
#  qualification_evidence_ids   :jsonb            not null
#  qualification_snapshot       :jsonb            not null
#  starts_at                    :datetime         not null
#  status                       :integer          default("confirmed"), not null
#  timezone                     :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  account_id                   :bigint           not null
#  assignee_id                  :bigint
#  calendar_id                  :string           not null
#  confirmation_message_id      :string
#  contact_id                   :bigint           not null
#  conversation_id              :bigint           not null
#  lead_qualification_id        :bigint           not null
#  provider_event_id            :string
#
# Indexes
#
#  index_bookings_on_account_id             (account_id)
#  index_bookings_on_active_slot            (account_id,calendar_id,starts_at) UNIQUE WHERE (status = 0)
#  index_bookings_on_active_slot_overlap    (account_id, calendar_id, tsrange(starts_at, ends_at, '[)'::text)) WHERE (status = 0) USING gist
#  index_bookings_on_assignee_id            (assignee_id)
#  index_bookings_on_contact_id             (contact_id)
#  index_bookings_on_conversation_id        (conversation_id)
#  index_bookings_on_idempotency_key        (account_id,idempotency_key) UNIQUE WHERE (idempotency_key IS NOT NULL)
#  index_bookings_on_lead_qualification_id  (lead_qualification_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (lead_qualification_id => lead_qualifications.id)
#
class Booking < ApplicationRecord
  belongs_to :account
  belongs_to :contact
  belongs_to :conversation
  belongs_to :lead_qualification
  belongs_to :assignee, class_name: 'User', optional: true

  enum status: {
    confirmed: 0,
    canceled: 1,
    completed: 2
  }

  validates :calendar_id, :provider, :starts_at, :ends_at, :timezone, :status, presence: true
  validates :starts_at, uniqueness: { scope: [:account_id, :calendar_id], conditions: -> { confirmed } }
  validates :idempotency_key, uniqueness: { scope: :account_id }, allow_blank: true
  validate :ends_after_start
  validate :active_slot_does_not_overlap
  validate :records_belong_to_account

  scope :active, -> { confirmed }

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, 'must be after starts_at') unless ends_at > starts_at
  end

  def records_belong_to_account
    errors.add(:contact, 'must belong to the same account') if contact.present? && contact.account_id != account_id
    errors.add(:conversation, 'must belong to the same account') if conversation.present? && conversation.account_id != account_id
    return unless lead_qualification.present? && lead_qualification.account_id != account_id

    errors.add(:lead_qualification, 'must belong to the same account')
  end

  def active_slot_does_not_overlap
    return unless confirmed? && starts_at.present? && ends_at.present? && account_id.present? && calendar_id.present?

    overlapping_booking = Booking.active
                                 .where(account_id: account_id, calendar_id: calendar_id)
                                 .where.not(id: id)
                                 .exists?(['starts_at < ? AND ends_at > ?', ends_at, starts_at])
    errors.add(:starts_at, 'overlaps an active booking') if overlapping_booking
  end
end
