# frozen_string_literal: true

class AiLeadEmployee::OfferPricingResolver
  Result = Struct.new(:answer, :sources, :refusal_reason, :variant, keyword_init: true) do
    def answered?
      answer.present?
    end

    def refused?
      refusal_reason.present?
    end
  end

  def initialize(account:, offer:, at: Time.current, promotion_eligible: nil)
    @account = account
    @offer = offer
    @at = at.in_time_zone
    @promotion_eligible = promotion_eligible
  end

  def perform
    return refused('offer_not_selected') unless offer && offer.account_id == account.id && offer.enabled?

    term = account.offer_commercial_terms.includes(:published_revision).find_by(offer_id: offer.id)
    revision = term&.published_revision
    return refused('no_published_price') unless revision

    snapshot = revision.snapshot.deep_stringify_keys
    return refused('price_not_current') unless current?(snapshot)

    variant = pricing_variant(snapshot)
    Result.new(
      answer: answer(snapshot, variant),
      sources: [source(revision, snapshot, variant)],
      refusal_reason: nil,
      variant: variant
    )
  end

  private

  attr_reader :account, :offer, :at, :promotion_eligible

  def refused(reason)
    Result.new(answer: nil, sources: [], refusal_reason: reason, variant: nil)
  end

  def current?(snapshot)
    starts_at = parsed(snapshot['effective_from'])
    ends_at = parsed(snapshot['effective_until'])
    (starts_at.nil? || at >= starts_at) && (ends_at.nil? || at < ends_at)
  end

  def pricing_variant(snapshot)
    return 'quote_required' if snapshot['quote_required']
    return 'standard' unless promotion_current?(snapshot)
    return 'standard' if snapshot['promotion_requires_confirmation'] && promotion_eligible != true

    'promotion'
  end

  def promotion_current?(snapshot)
    return false unless snapshot['promotion_amount_minor']

    starts_at = parsed(snapshot['promotion_starts_at'])
    ends_at = parsed(snapshot['promotion_ends_at'])
    starts_at && ends_at && at >= starts_at && at < ends_at
  end

  def answer(snapshot, variant)
    parts = if variant == 'quote_required'
              ["Pricing for #{offer.name} requires a quote."]
            else
              amount_key = variant == 'promotion' ? 'promotion_amount_minor' : 'amount_minor'
              ["The published price for #{offer.name} is #{snapshot['currency']} #{format_amount(snapshot[amount_key], snapshot['currency'])}."]
            end
    parts << snapshot['conditions'] if snapshot['conditions'].present?
    parts << snapshot['promotion_conditions'] if variant == 'promotion' && snapshot['promotion_conditions'].present?
    parts << "Pricing or purchase link: #{snapshot['pricing_url']}" if snapshot['pricing_url'].present?
    parts.join(' ')
  end

  def format_amount(amount_minor, currency)
    AiLeadEmployee::OfferMoney.format(amount_minor, currency)
  end

  def source(revision, snapshot, variant)
    {
      id: revision.id,
      type: 'offer_commercial_terms',
      source_kind: 'pricing',
      status: 'verified',
      offer_id: offer.id,
      offer_configuration_version: offer.configuration_version,
      commercial_revision: revision.revision,
      commercial_revision_id: revision.id,
      content_digest: revision.content_digest,
      pricing_variant: variant,
      promotion_eligible: promotion_eligible,
      effective_until: snapshot['effective_until'],
      promotion_ends_at: snapshot['promotion_ends_at']
    }.compact
  end

  def parsed(value)
    Time.iso8601(value) if value.present?
  end
end
