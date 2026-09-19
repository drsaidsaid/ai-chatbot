# frozen_string_literal: true

class AiLeadEmployee::OfferAnswerContext
  def self.capture(conversation:, offer:, sources: [])
    return {} if offer.blank?

    context = {
      'scope' => 'offer_answer',
      'account_id' => conversation.account_id,
      'contact_id' => conversation.contact_id,
      'origin_conversation_id' => conversation.id,
      'offer_id' => offer.id,
      'selection_version' => conversation.offer_selection_version,
      'configuration_version' => offer.configuration_version
    }
    commercial_source = Array(sources).find { |source| source.with_indifferent_access[:type] == 'offer_commercial_terms' }
    context['commercial_terms'] = commercial_context(commercial_source) if commercial_source
    context.freeze
  end

  def self.commercial_context(source)
    values = source.with_indifferent_access
    {
      'revision_id' => values[:commercial_revision_id],
      'content_digest' => values[:content_digest],
      'pricing_variant' => values[:pricing_variant],
      'promotion_eligible' => values[:promotion_eligible]
    }
  end
  private_class_method :commercial_context

  def initialize(conversation:, context:)
    @conversation = conversation
    @context = context.is_a?(Hash) ? context : {}
  end

  def failure_code
    return if context.empty?
    return 'qualification_context_invalid' unless valid_identity?
    return 'offer_selection_changed' unless current_selection?

    offer = AiLeadEmployee::Offer.find_by(account_id: conversation.account_id, id: context['offer_id'])
    return 'offer_configuration_changed' unless offer&.enabled? && offer.configuration_version == context['configuration_version']

    commercial_terms_failure(offer)
  end

  private

  attr_reader :conversation, :context

  def valid_identity?
    context['scope'] == 'offer_answer' && context['account_id'] == conversation.account_id &&
      context['contact_id'] == conversation.contact_id && context['origin_conversation_id'] == conversation.id &&
      %w[offer_id selection_version configuration_version].all? { |key| context[key].is_a?(Integer) }
  end

  def current_selection?
    conversation.offer_id == context['offer_id'] && conversation.offer_selection_version == context['selection_version']
  end

  def commercial_terms_failure(offer) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    commercial = context['commercial_terms']
    return if commercial.blank?
    return 'offer_price_context_invalid' unless valid_commercial_context?(commercial)

    term = AiLeadEmployee::OfferCommercialTerm.find_by(account_id: conversation.account_id, offer_id: offer.id)
    revision = term&.published_revision
    return 'offer_price_changed' unless revision&.id == commercial['revision_id'] &&
                                        revision.content_digest == commercial['content_digest']

    current = AiLeadEmployee::OfferPricingResolver.new(
      account: conversation.account,
      offer: offer,
      promotion_eligible: AiLeadEmployee::PromotionEligibility.new(conversation: conversation, offer: offer).value
    ).perform
    return 'offer_price_not_current' if current.refused? || current.variant != commercial['pricing_variant']
  end

  def valid_commercial_context?(commercial)
    commercial.is_a?(Hash) && commercial['revision_id'].is_a?(Integer) &&
      commercial['content_digest'].is_a?(String) && commercial['pricing_variant'].in?(%w[standard promotion quote_required])
  end
end
