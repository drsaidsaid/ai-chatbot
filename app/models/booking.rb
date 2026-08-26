# frozen_string_literal: true

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
