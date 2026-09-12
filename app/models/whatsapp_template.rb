# frozen_string_literal: true

class WhatsappTemplate < ApplicationRecord
  belongs_to :account
  belongs_to :channel, class_name: 'Channel::Whatsapp'
  belongs_to :created_by, class_name: 'User'
  has_many :revisions, class_name: 'WhatsappTemplateRevision', dependent: :restrict_with_exception

  validates :name, presence: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :name, uniqueness: { scope: %i[account_id channel_id] }
  validate :channel_belongs_to_account

  def latest_revision = revisions.order(revision_number: :desc).first

  private

  def channel_belongs_to_account
    errors.add(:channel, 'must belong to the Business Account') if channel && channel.account_id != account_id
  end
end
