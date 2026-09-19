# frozen_string_literal: true

require 'uri'

class AiLeadEmployee::CommercialTerms
  class Conflict < StandardError; end

  def self.normalize(attributes, publishable: false) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    values = attributes.to_h.deep_stringify_keys
    currency = values.fetch('currency')
    raise ArgumentError, 'Unsupported currency' unless AiLeadEmployee::OfferMoney::PRECISION.key?(currency)

    timezone = values['timezone'].presence || 'UTC'
    Time.find_zone!(timezone)
    quote_required = ActiveModel::Type::Boolean.new.cast(values['quote_required'])
    amount_minor = quote_required ? nil : AiLeadEmployee::OfferMoney.parse(values['amount'], currency)
    raise ArgumentError, 'Enter an amount or choose quote required' if !quote_required && amount_minor.nil?

    snapshot = {
      'currency' => currency,
      'amount_minor' => amount_minor,
      'quote_required' => quote_required,
      'timezone' => timezone,
      'effective_from' => parse_time(values['effective_from'], timezone),
      'effective_until' => parse_time(values['effective_until'], timezone),
      'conditions' => values['conditions'].to_s.strip.presence,
      'pricing_url' => normalized_url(values['pricing_url']),
      'promotion_amount_minor' => AiLeadEmployee::OfferMoney.parse(values['promotion_amount'], currency),
      'promotion_starts_at' => parse_time(values['promotion_starts_at'], timezone),
      'promotion_ends_at' => parse_time(values['promotion_ends_at'], timezone),
      'promotion_conditions' => values['promotion_conditions'].to_s.strip.presence,
      'promotion_requires_confirmation' => ActiveModel::Type::Boolean.new.cast(values['promotion_requires_confirmation']),
      'promotion_eligibility_field' => values['promotion_eligibility_field'].to_s.strip.presence
    }.compact
    validate_ranges!(snapshot, publishable: publishable)
    snapshot
  rescue TZInfo::InvalidTimezoneIdentifier
    raise ArgumentError, 'Choose a valid timezone'
  end

  def self.public_snapshot(snapshot)
    values = snapshot.to_h.deep_stringify_keys
    currency = values['currency']
    values.except('amount_minor', 'promotion_amount_minor').merge(
      'amount' => AiLeadEmployee::OfferMoney.format(values['amount_minor'], currency),
      'promotion_amount' => AiLeadEmployee::OfferMoney.format(values['promotion_amount_minor'], currency),
      'effective_from' => local_time(values['effective_from'], values['timezone']),
      'effective_until' => local_time(values['effective_until'], values['timezone']),
      'promotion_starts_at' => local_time(values['promotion_starts_at'], values['timezone']),
      'promotion_ends_at' => local_time(values['promotion_ends_at'], values['timezone'])
    ).compact
  end

  def self.local_time(value, timezone)
    return if value.blank?

    Time.iso8601(value).in_time_zone(timezone).strftime('%Y-%m-%dT%H:%M')
  end
  private_class_method :local_time

  def self.digest(snapshot)
    Digest::SHA256.hexdigest(snapshot.deep_stringify_keys.sort.to_h.to_json)
  end

  def self.parse_time(value, timezone)
    return if value.blank?

    Time.use_zone(timezone) { Time.zone.parse(value.to_s)&.utc&.iso8601(6) } || raise(ArgumentError, 'Invalid effective time')
  rescue ArgumentError
    raise ArgumentError, 'Invalid effective time'
  end
  private_class_method :parse_time

  def self.normalized_url(value)
    return if value.blank?

    uri = URI.parse(value.to_s)
    raise ArgumentError unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  rescue URI::InvalidURIError, ArgumentError
    raise ArgumentError, 'Pricing link must use HTTP or HTTPS'
  end
  private_class_method :normalized_url

  def self.validate_ranges!(snapshot, publishable:) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    if snapshot['effective_from'] && snapshot['effective_until'] && snapshot['effective_until'] <= snapshot['effective_from']
      raise ArgumentError, 'Effective end must be after the start'
    end

    promotion_fields = snapshot.values_at('promotion_starts_at', 'promotion_ends_at')
    missing_promotion_range = publishable && snapshot['promotion_amount_minor'] && promotion_fields.any?(&:nil?)
    raise ArgumentError, 'Promotion start and end are required' if missing_promotion_range

    raise ArgumentError, 'Promotion amount is required' if promotion_fields.compact.any? && snapshot['promotion_amount_minor'].nil?

    invalid_quote_promotion = snapshot['quote_required'] && snapshot['promotion_amount_minor']
    raise ArgumentError, 'Quote-required Offers cannot publish a promotional amount' if invalid_quote_promotion
    if publishable && snapshot['promotion_requires_confirmation'] && snapshot['promotion_eligibility_field'].blank?
      raise ArgumentError, 'Choose the boolean Offer field that confirms promotion eligibility'
    end
    return unless promotion_fields.none?(&:nil?) && promotion_fields.last <= promotion_fields.first

    raise ArgumentError, 'Promotion end must be after the start'
  end
  private_class_method :validate_ranges!

  def self.save_draft!(offer:, attributes:, expected_version: nil)
    offer.class.transaction do
      offer.lock!
      record = offer.commercial_term || offer.build_commercial_term(account: offer.account)
      record.lock! if record.persisted?
      raise Conflict, 'Commercial terms changed; reload before saving' if record.persisted? && expected_version.nil?
      raise Conflict, 'Commercial terms changed; reload before saving' if expected_version && record.draft_version != expected_version.to_i

      record.draft = normalize(attributes)
      record.draft_version += 1
      record.save!
      record
    end
  end

  def self.publish!(offer:, expected_version:, editor:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    offer.class.transaction do
      offer.lock!
      record = offer.commercial_term&.lock!
      raise ArgumentError, 'Save commercial terms before publishing' if record&.draft.blank?
      raise Conflict, 'Commercial terms changed; reload before publishing' unless record.draft_version == expected_version.to_i

      snapshot = normalize(public_snapshot(record.draft), publishable: true)
      validate_promotion_field!(offer, snapshot)
      revision_number = record.revisions.maximum(:revision).to_i + 1
      revision = record.revisions.create!(
        account: offer.account,
        offer: offer,
        published_by: editor,
        revision: revision_number,
        snapshot: snapshot,
        content_digest: digest(snapshot),
        published_at: Time.current
      )
      record.update!(published_revision: revision)
      offer.update!(configuration_version: offer.configuration_version + 1)
      offer.configuration_revisions.create!(account: offer.account, version: offer.configuration_version, snapshot: offer.payload)
      revision
    end
  end

  def self.validate_promotion_field!(offer, snapshot)
    return unless snapshot['promotion_requires_confirmation']

    question = offer.configuration.fetch('questions', []).find do |candidate|
      candidate['key'] == snapshot['promotion_eligibility_field'] && candidate['enabled'] && candidate['answer_type'] == 'boolean'
    end
    raise ArgumentError, 'Promotion eligibility must use an enabled boolean Offer field' unless question
  end
  private_class_method :validate_promotion_field!
end
