# frozen_string_literal: true

class WhatsappTemplateRevision < ApplicationRecord
  belongs_to :whatsapp_template
  belongs_to :account
  belongs_to :channel, class_name: 'Channel::Whatsapp'
  belongs_to :submitted_by, class_name: 'User', optional: true

  enum :status, { draft: 0, submission_pending: 1, submitted: 2, approved: 3, rejected: 4, paused: 5, disabled: 6, unknown: 7,
                  submitting: 8 }

  validates :revision_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :whatsapp_template_id }
  validates :language, :category, :body, :submission_key, :content_digest, presence: true
  validates :category, inclusion: { in: %w[AUTHENTICATION MARKETING UTILITY] }
  validate :template_and_channel_match_account
  validate :variable_placeholders_are_declared
  validate :meta_charge_estimate_is_complete
  validate :submitted_content_is_immutable, on: :update

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

  def meta_charge_estimate_is_complete
    estimate = meta_charge_estimate.to_h
    return if estimate.empty?

    required = %w[amount currency market effective_on source]
    errors.add(:meta_charge_estimate, 'must include amount, currency, market, date, and source') if required.any? { |key| estimate[key].blank? }
    amount = Float(estimate['amount'])
    errors.add(:meta_charge_estimate, 'amount cannot be negative') if amount.negative?
  rescue ArgumentError, TypeError
    errors.add(:meta_charge_estimate, 'amount must be a number')
  end

  def submitted_content_is_immutable
    return if submitted_at_was.blank?

    immutable = %w[account_id channel_id whatsapp_template_id revision_number language category body media buttons variables content_digest
                   submission_key meta_charge_estimate]
    errors.add(:base, 'Submitted template content is immutable') if immutable.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end
end
