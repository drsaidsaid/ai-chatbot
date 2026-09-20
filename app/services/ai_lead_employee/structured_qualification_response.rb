# frozen_string_literal: true

require 'json'
require 'bigdecimal'

class AiLeadEmployee::StructuredQualificationResponse # rubocop:disable Metrics/ClassLength
  Result = Struct.new(:reply, :observations, :localized_prompts, :malformed, :diagnostics, keyword_init: true) do
    def malformed? = malformed
  end
  GOAL_OR_FUTURE = /\b(?:goal|target|aim|plan|planning|want|would like|hope|future|lengo|malengo|nataka|ningependa|
                    natarajia|mpango|mipango|kufikia|nitafikia)\b/ix
  GOAL_FIELD = /\b(?:goal|target|aim|desired|future|lengo|malengo)\b/i
  INTENT_BOOLEAN_FIELD = /\b(?:willing|willingness|ready|readiness|interested|would you|ungependa|uko tayari)\b/i
  POSITIVE_INTENT = /\b(?:want|would like|willing|ready|interested|nataka|ningependa|niko tayari|uko tayari)\b/i
  NEGATION = /\b(?:no|not|never|without|don't|dont|cannot|can't|sina|hapana|si|sio|siyo|bila)\b/i
  HYPOTHETICAL = /\b(?:if|would|could|might|maybe|perhaps|ikiwa|endapo|labda)\b/i
  THIRD_PARTY = /\b(?:he|she|they|them|his|her|their|friend|partner|spouse|rafiki|yeye|wao)\b/i
  MONTHLY = /\b(?:monthly|per month|kwa mwezi)\b/i
  YEARLY = /\b(?:yearly|annually|annual|per year|kwa mwaka)\b/i
  CLAUSE_SPLIT = /(?<=[.!?])\s+|[,;]\s+|\s+\b(?:and|but|na|lakini)\b\s+/i

  def initialize(content:, offer:, incoming_message:)
    @content = content.to_s
    @offer = offer
    @incoming_message = incoming_message
  end

  def perform # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return fallback unless offer&.enabled? && offer.questions.present?

    payload = JSON.parse(content)
    return fallback unless payload.is_a?(Hash) && payload['reply'].is_a?(String)
    return fallback if payload.key?('observations') && !payload['observations'].is_a?(Array)

    parsed_observations, diagnostics = observations(Array(payload['observations']))
    Result.new(
      reply: payload['reply'],
      observations: parsed_observations,
      localized_prompts: localized_prompts(payload['localized_prompts']),
      malformed: false,
      diagnostics: diagnostics
    )
  rescue JSON::ParserError
    fallback
  end

  private

  attr_reader :content, :offer, :incoming_message

  def observations(candidates) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    rejections = []
    candidate_keys = []
    accepted = candidates.filter_map do |candidate|
      key, observation, rejection = observation_result(candidate)
      candidate_keys << key if configured_field_key?(key)
      rejections << rejection_payload(key, rejection) if rejection
      [key, observation] if observation
    end
    grouped = accepted.group_by(&:first)
    observations = grouped.filter_map do |key, values|
      if conflicting?(values.map(&:last))
        rejections << rejection_payload(key, 'conflicting_candidates')
        next
      end

      [key, values.first.last]
    end.to_h
    [observations, diagnostics(candidates: candidates, candidate_keys: candidate_keys, observations: observations, rejections: rejections)]
  end

  def conflicting?(values)
    values.map { |value| value.except('quote') }.uniq.many?
  end

  def fallback
    Result.new(reply: nil, observations: {}, localized_prompts: {}, malformed: true,
               diagnostics: diagnostics(candidates: [], candidate_keys: [], observations: {}, rejections: [], malformed: true))
  end

  def observation_result(candidate) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return [nil, nil, 'invalid_candidate'] unless candidate.is_a?(Hash)

    values = candidate.stringify_keys
    key = values['key'].to_s
    quote = values['quote'].to_s
    question = offer.questions.find { |field| field['key'] == key }
    return [nil, nil, 'unsupported_field'] unless question
    return [key, nil, 'disabled_field'] if question['enabled'] == false
    return [key, nil, 'missing_candidate'] if quote.blank?
    return [key, nil, 'quote_context'] unless incoming_message.content.to_s.include?(quote)
    return [key, nil, 'action_agreement'] if action_agreement?(key)
    return [key, nil, 'missing_candidate'] unless asserted_candidate?(values)

    quote_rejection = asserted_quote_rejection(question, quote, values)
    return [key, nil, quote_rejection] if quote_rejection

    typed, rejection = validated_observation(question, quote, values)
    return [key, nil, rejection] unless typed

    [key, typed.merge('asserted' => true, 'quote' => quote), nil]
  end

  def action_agreement?(key)
    key == offer.next_step['agreement_field'] || %w[sales_call_agreement appointment_agreement].include?(key)
  end

  def asserted_candidate?(candidate)
    candidate['asserted'] == true && candidate['certainty'] == 'certain'
  end

  def asserted_quote_rejection(question, quote, candidate) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    context = containing_clause(quote)
    return 'quote_context' if context.include?('?')
    return 'quote_context' if context.match?(HYPOTHETICAL) || context.match?(THIRD_PARTY)
    return 'quote_context' if context.match?(GOAL_OR_FUTURE) && !goal_field?(question) && !intent_boolean_field?(question)
    return 'quote_context' if context.match?(NEGATION) && !negative_value?(question, candidate)
    return 'quote_context' if unsupported_positive_intent?(question, context, candidate)

    return 'quote_context' unless quote.split.size >= 2 || question['answer_type'] == 'number'

    nil
  end

  def containing_clause(quote)
    incoming_message.content.to_s.split(CLAUSE_SPLIT).find { |clause| clause.include?(quote) }.presence || quote
  end

  def goal_field?(question)
    [question['key'], question['meaning'], question['prompt']].compact.join(' ').match?(GOAL_FIELD)
  end

  def intent_boolean_field?(question)
    question['answer_type'] == 'boolean' &&
      [question['key'], question['meaning'], question['prompt']].compact.join(' ').match?(INTENT_BOOLEAN_FIELD)
  end

  def unsupported_positive_intent?(question, context, candidate)
    intent_boolean_field?(question) && candidate['typed_value'] == true && !context.match?(POSITIVE_INTENT)
  end

  def negative_value?(question, candidate)
    return true if question['answer_type'] == 'boolean' && candidate['typed_value'] == false
    return true if question['answer_type'] == 'choice' && candidate['typed_value'].to_s.match?(/\b(?:no|not|none|negative)\b/)

    false
  end

  def validated_observation(question, quote, candidate) # rubocop:disable Metrics/CyclomaticComplexity
    typed, rejection = case question['answer_type']
                       when 'choice' then choice_observation(question, quote, candidate)
                       when 'boolean' then boolean_observation(quote, candidate)
                       when 'money' then money_observation(question, quote, candidate)
                       when 'number' then number_observation(quote, candidate)
                       when 'text' then text_observation(quote, candidate)
                       else [nil, 'typed_mismatch']
                       end
    return [nil, rejection] unless typed

    [typed.merge('value' => quote, 'polarity' => typed['typed_value'] == false ? 'negative' : 'positive'), nil]
  end

  def choice_observation(question, _quote, candidate)
    value = candidate['typed_value']
    return [nil, 'typed_mismatch'] unless value.is_a?(String) && question.fetch('options', []).include?(value)

    [{ 'typed_value' => value }, nil]
  end

  def boolean_observation(_quote, candidate)
    value = candidate['typed_value']
    return [nil, 'typed_mismatch'] unless [true, false].include?(value)

    [{ 'typed_value' => value }, nil]
  end

  def money_observation(question, quote, candidate)
    money = AiLeadEmployee::QualificationAmountParser.parse(quote, default_currency: offer.currency)
    return [nil, 'typed_mismatch'] unless money
    return [nil, 'currency_period'] unless money['currency'] == offer.currency
    return [nil, 'typed_mismatch'] unless candidate['typed_value'] == money['amount_minor']
    return [nil, 'currency_period'] unless period_matches?(quote, question['period'])

    [{ 'typed_value' => money['amount_minor'], 'amount_minor' => money['amount_minor'],
       'currency' => money['currency'], 'period' => question['period'] }, nil]
  end

  def number_observation(quote, candidate)
    matches = quote.scan(/(?<![\w.])\d+(?:\.\d+)?(?![\w.])/)
    return [nil, 'typed_mismatch'] unless matches.one?

    value = BigDecimal(matches.first)
    candidate_value = BigDecimal(candidate['typed_value'].to_s)
    return [nil, 'typed_mismatch'] unless candidate_value == value

    [{ 'typed_value' => value.frac.zero? ? value.to_i : value.to_f }, nil]
  rescue ArgumentError
    [nil, 'typed_mismatch']
  end

  def text_observation(quote, candidate)
    value = candidate['typed_value']
    return [nil, 'typed_mismatch'] unless value.is_a?(String) && value == quote && quote.split.size.between?(1, 30)

    [{ 'typed_value' => value }, nil]
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

  def configured_field_keys
    @configured_field_keys ||= offer&.questions.to_a.filter_map do |field|
      field['key'] if field['enabled'] != false
    end
  end

  def configured_field_key?(key)
    key.present? && configured_field_keys.include?(key)
  end

  def rejection_payload(key, code)
    { 'field_key' => configured_field_key?(key) ? key : nil, 'code' => code }
  end

  def diagnostics(candidates:, candidate_keys:, observations:, rejections:, malformed: false)
    {
      'malformed' => malformed,
      'configured_field_keys' => configured_field_keys,
      'candidate_count' => candidates.size,
      'known_candidate_count' => candidate_keys.size,
      'accepted_count' => observations.size,
      'accepted_field_keys' => observations.keys.sort,
      'rejected_count' => rejections.size,
      'rejection_counts' => rejections.pluck('code').compact.tally,
      'rejected_field_keys_by_code' => rejected_field_keys_by_code(rejections),
      'absent_candidate_field_keys' => (configured_field_keys - candidate_keys.uniq).sort
    }
  end

  def rejected_field_keys_by_code(rejections)
    grouped = rejections.each_with_object({}) do |rejection, memo|
      next if rejection['field_key'].blank?

      memo[rejection['code']] ||= []
      memo[rejection['code']] << rejection['field_key']
    end
    grouped.transform_values { |keys| keys.uniq.sort }
  end
end
