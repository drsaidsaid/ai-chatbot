# frozen_string_literal: true

class WhatsappTemplateRevision < ApplicationRecord
  belongs_to :whatsapp_template
  belongs_to :account
  belongs_to :channel, class_name: 'Channel::Whatsapp'
  belongs_to :submitted_by, class_name: 'User', optional: true

  enum :status, { draft: 0, submission_pending: 1, submitted: 2, approved: 3, rejected: 4, paused: 5, disabled: 6, unknown: 7 }

  validates :revision_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :whatsapp_template_id }
  validates :language, :category, :body, :submission_key, :content_digest, presence: true
  validates :category, inclusion: { in: %w[AUTHENTICATION MARKETING UTILITY] }
  validate :template_and_channel_match_account
  validate :variable_placeholders_are_declared

  def sendable? = approved? && provider_template_id.present?

  def meta_approval = submitted_at? ? status : 'not_submitted'

  def preview
    { 'body' => body, 'media' => media, 'buttons' => buttons, 'variables' => variables, 'language' => language }
  end

  private

  def template_and_channel_match_account
    errors.add(:whatsapp_template, 'must belong to the Business Account') if whatsapp_template && whatsapp_template.account_id != account_id
    errors.add(:channel, 'must belong to the Business Account') if channel && channel.account_id != account_id
  end

  def variable_placeholders_are_declared
    placeholders = body.to_s.scan(/\{\{\s*(\d+)\s*\}\}/).flatten.map(&:to_i).uniq.sort
    declared = Array(variables).map { |item| item.is_a?(Hash) ? (item['position'] || item[:position]).to_i : item.to_i }.sort
    errors.add(:variables, 'must declare every body placeholder exactly once') unless placeholders == declared
  end
end
