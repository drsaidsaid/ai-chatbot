# frozen_string_literal: true

class AiLeadEmployee::OfferAnswerContext
  def self.capture(conversation:, offer:)
    return {} if offer.blank?

    {
      'scope' => 'offer_answer',
      'account_id' => conversation.account_id,
      'contact_id' => conversation.contact_id,
      'origin_conversation_id' => conversation.id,
      'offer_id' => offer.id,
      'selection_version' => conversation.offer_selection_version,
      'configuration_version' => offer.configuration_version
    }.freeze
  end

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
end
