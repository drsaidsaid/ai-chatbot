# frozen_string_literal: true

class WhatsappTemplateRevision < ApplicationRecord
  belongs_to :whatsapp_template
  belongs_to :account
  belongs_to :channel, class_name: 'Channel::Whatsapp'
  belongs_to :submitted_by, class_name: 'User', optional: true

  enum :status, { draft: 0, submission_pending: 1, submitted: 2, approved: 3, rejected: 4, paused: 5, disabled: 6, unknown: 7,
                  submitting: 8, submission_failed: 9 }

  validates :revision_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :whatsapp_template_id }
  validates :language, :category, :body, :submission_key, :content_digest, presence: true
  validates :category, inclusion: { in: %w[AUTHENTICATION MARKETING UTILITY] }
  validate :template_and_channel_match_account
  validate :variable_placeholders_are_declared
  validate :component_examples_are_submittable
  validate :meta_charge_estimate_is_complete
  validate :provider_template_language_is_immutable
  validate :submitted_content_is_immutable, on: :update

  def sendable?
    approved? && provider_template_id.present? && whatsapp_template.latest_revision&.id == id
  end

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

  def component_examples_are_submittable
    validate_variable_examples
    validate_media_example
    validate_buttons
  end

  def validate_variable_examples
    errors.add(:variables, 'must include a sample value for every placeholder') if Array(variables).any? do |variable|
      variable.to_h['example'].blank?
    end
  end

  def validate_media_example
    media_attributes = media.to_h
    return if media_attributes.empty?

    errors.add(:media, 'format must be IMAGE, VIDEO, or DOCUMENT') unless %w[IMAGE VIDEO DOCUMENT].include?(media_attributes['format'])
    handles = media_attributes.dig('example', 'header_handle')
    errors.add(:media, 'must include a sample header handle') if !handles.is_a?(Array) || handles.none?(&:present?)
  end

  def validate_buttons
    Array(buttons).each { |button| validate_button(button.to_h) }
  end

  def validate_button(attributes)
    type = attributes['type']
    errors.add(:buttons, 'type must be QUICK_REPLY, URL, or PHONE_NUMBER') unless %w[QUICK_REPLY URL PHONE_NUMBER].include?(type)
    errors.add(:buttons, 'text is required') if attributes['text'].blank?
    errors.add(:buttons, 'URL buttons require a URL') if type == 'URL' && attributes['url'].blank?
    errors.add(:buttons, 'phone buttons require a phone number') if type == 'PHONE_NUMBER' && attributes['phone_number'].blank?
  end

  def meta_charge_estimate_is_complete
    estimate = meta_charge_estimate.to_h
    return if estimate.empty?

    required = %w[amount currency market effective_on source authority verified_by_user_id verified_at]
    if required.any? { |key| estimate[key].blank? }
      errors.add(:meta_charge_estimate, 'must include amount, currency, market, date, source, and verification')
    end
    if estimate['authority'].present? && estimate['authority'] != 'business_account_admin'
      errors.add(:meta_charge_estimate, 'has an unsupported verification authority')
    end
    validate_estimate_amount(estimate['amount'])
  end

  def validate_estimate_amount(value)
    amount = Float(value)
    errors.add(:meta_charge_estimate, 'amount cannot be negative') if amount.negative?
  rescue ArgumentError, TypeError
    errors.add(:meta_charge_estimate, 'amount must be a number')
  end

  def provider_template_language_is_immutable
    return unless whatsapp_template && revision_number

    provider_language = whatsapp_template.revisions
                                         .where('revision_number < ?', revision_number)
                                         .where.not(provider_template_id: [nil, ''])
                                         .order(revision_number: :desc)
                                         .pick(:language)
    errors.add(:language, 'cannot change when editing an existing Meta template') if provider_language.present? && language != provider_language
  end

  def submitted_content_is_immutable
    return if submitted_at_was.blank?

    immutable = %w[account_id channel_id whatsapp_template_id revision_number language category body media buttons variables content_digest
                   submission_key meta_charge_estimate]
    errors.add(:base, 'Submitted template content is immutable') if immutable.any? { |attribute| will_save_change_to_attribute?(attribute) }
  end
end
