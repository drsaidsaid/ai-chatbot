# frozen_string_literal: true

require 'json'
require 'bigdecimal'

class AiLeadEmployee::StructuredQualificationResponse
  Result = Struct.new(:reply, :observations, :localized_prompts, :malformed, keyword_init: true) do
    def malformed? = malformed
  end
  GOAL_OR_FUTURE = /\b(?:goal|target|aim|plan|planning|want|would like|hope|future|lengo|malengo|nataka|ningependa|
                    natarajia|mpango|mipango|kufikia|nitafikia)\b/ix
  NEGATION = /\b(?:no|not|never|without|don't|dont|cannot|can't|sina|hapana|si|sio|siyo|bila)\b/i
  HYPOTHETICAL = /\b(?:if|would|could|might|maybe|perhaps|ikiwa|endapo|labda)\b/i
  MONTHLY = /\b(?:monthly|per month|kwa mwezi)\b/i
  YEARLY = /\b(?:yearly|annually|annual|per year|kwa mwaka)\b/i

  def initialize(content:, offer:, incoming_message:)
    @content = content.to_s
    @offer = offer
    @incoming_message = incoming_message
  end

  def perform
    payload = JSON.parse(content)
    return fallback unless payload.is_a?(Hash) && payload['reply'].is_a?(String)
    return fallback if payload.key?('observations') && !payload['observations'].is_a?(Array)

    Result.new(
      reply: payload['reply'],
      observations: Array(payload['observations']).filter_map { |candidate| observation(candidate) }.to_h,
      localized_prompts: localized_prompts(payload['localized_prompts']),
      malformed: false
    )
  rescue JSON::ParserError
    fallback
  end

  private

  attr_reader :content, :offer, :incoming_message

  def fallback
    Result.new(reply: nil, observations: {}, localized_prompts: {}, malformed: true)
  end

  def observation(candidate) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return unless candidate.is_a?(Hash)

    values = candidate.stringify_keys
    key = values['key'].to_s
    quote = values['quote'].to_s
    question = offer.questions.find { |field| field['key'] == key }
    return unless question && question['enabled'] != false && quote.present? && incoming_message.content.to_s.include?(quote)
    return if action_agreement?(key)
    return unless asserted_candidate?(values)
    return unless asserted_quote?(quote)

    typed = validated_observation(question, quote, values)
    return unless typed

    [key, typed.merge('asserted' => true, 'quote' => quote)]
  end

  def action_agreement?(key)
    key == offer.next_step['agreement_field'] || %w[sales_call_agreement appointment_agreement].include?(key)
  end

  def asserted_candidate?(candidate)
    candidate['asserted'] == true && candidate['certainty'] == 'certain'
  end

  def asserted_quote?(quote)
    return false if quote.include?('?')
    return false if quote.match?(GOAL_OR_FUTURE) || quote.match?(NEGATION) || quote.match?(HYPOTHETICAL)

    quote.split.size >= 2
  end

  def validated_observation(question, quote, candidate) # rubocop:disable Metrics/CyclomaticComplexity
    typed = case question['answer_type']
            when 'choice' then choice_observation(question, quote, candidate)
            when 'boolean' then boolean_observation(quote, candidate)
            when 'money' then money_observation(question, quote, candidate)
            when 'number' then number_observation(quote, candidate)
            when 'text' then text_observation(quote, candidate)
            end
    typed&.merge('value' => quote, 'polarity' => typed['typed_value'] == false ? 'negative' : 'positive')
  end

  def choice_observation(question, _quote, candidate)
    value = candidate['typed_value']
    return unless value.is_a?(String) && question.fetch('options', []).include?(value)

    { 'typed_value' => value }
  end

  def boolean_observation(_quote, candidate)
    value = candidate['typed_value']
    return unless [true, false].include?(value)

    { 'typed_value' => value }
  end

  def money_observation(question, quote, candidate)
    money = AiLeadEmployee::QualificationAmountParser.parse(quote, default_currency: offer.currency)
    return unless money && money['currency'] == offer.currency
    return unless candidate['typed_value'] == money['amount_minor']
    return unless period_matches?(quote, question['period'])

    { 'typed_value' => money['amount_minor'], 'amount_minor' => money['amount_minor'],
      'currency' => money['currency'], 'period' => question['period'] }
  end

  def number_observation(quote, candidate)
    return unless quote.match?(/\A\s*\d+(?:\.\d+)?\s*\z/)

    value = BigDecimal(quote)
    return unless candidate['typed_value'].to_s == value.to_s('F')

    { 'typed_value' => value.frac.zero? ? value.to_i : value.to_f }
  rescue ArgumentError
    nil
  end

  def text_observation(quote, candidate)
    value = candidate['typed_value']
    return unless value.is_a?(String) && value == quote && quote.split.size.between?(1, 30)

    { 'typed_value' => value }
  end

  def period_matches?(quote, period)
    return true if period.blank?

    case period
    when 'monthly', 'month' then quote.match?(MONTHLY)
    when 'yearly', 'annual', 'year' then quote.match?(YEARLY)
    else false
    end
  end

  def localized_prompts(value)
    return {} unless value.is_a?(Hash)

    value.filter_map do |key, prompt|
      question = offer.questions.find { |field| field['key'] == key.to_s }
      [key.to_s, prompt] if localized_prompt?(question, prompt)
    end.to_h
  end

  def localized_prompt?(question, prompt)
    question && question['enabled'] != false && prompt.is_a?(String) && prompt.present? && prompt.length <= 500
  end
end
