# frozen_string_literal: true

# A bounded typed comparison set, shared by configuration validation and evaluation.
class AiLeadEmployee::OfferRules
  BUILTIN_TYPES = {
    'business_type' => 'text', 'problem' => 'text', 'lead_volume' => 'number',
    'urgency' => 'text', 'budget' => 'money', 'decision_authority' => 'boolean',
    'contact_details' => 'text', 'name' => 'text', 'sales_call_agreement' => 'boolean'
  }.freeze
  POLARITY_OPERATORS = %w[positive negative known].freeze
  ORDERED_OPERATORS = %w[lt lte gt gte].freeze
  REQUIREMENT_DIMENSIONS = %w[fit readiness action_eligibility].freeze

  def self.normalize(rules, questions:, currency:)
    raise ArgumentError, 'Rules must be a list' unless rules.is_a?(Array)

    fields = BUILTIN_TYPES.transform_values { |type| { 'answer_type' => type } }.merge(questions.index_by { |question| question['key'] })
    rules.map do |rule|
      raise ArgumentError, 'Rule must be an object' unless rule.is_a?(Hash)

      field = fields.fetch(rule['field']) { raise ArgumentError, 'Unknown rule field' }
      validate_effect!(rule)
      value = normalize_value(rule, field, currency)
      rule.slice('kind', 'dimension', 'field', 'operator', 'score_delta', 'forced_outcome', 'priority', 'enabled').merge('value' => value)
    end
  end

  def self.validate_effect!(rule) # rubocop:disable Metrics/CyclomaticComplexity
    raise ArgumentError, 'Invalid rule priority' unless rule['priority'].is_a?(Integer) && rule['priority'] >= 0
    raise ArgumentError, 'Invalid rule enabled state' unless [true, false].include?(rule['enabled'])

    case rule['kind']
    when 'score_rule'
      validate_score_effect!(rule)
    when 'hard_rule'
      raise ArgumentError, 'Hard rules can only force unqualified' unless rule['forced_outcome'] == 'unqualified'
    when 'requirement'
      raise ArgumentError, 'Requirement needs a valid dimension' unless REQUIREMENT_DIMENSIONS.include?(rule['dimension'])
    else
      raise ArgumentError, 'Unsupported rule kind'
    end
  end

  def self.normalize_value(rule, field, currency)
    operator = rule['operator']
    return nil if POLARITY_OPERATORS.include?(operator)

    type = field.fetch('answer_type')
    validate_operator!(operator, type)
    normalize_comparison_value(type, rule['value'], field, currency, operator)
  end

  def self.validate_score_effect!(rule)
    raise ArgumentError, 'Score delta must be a nonnegative integer' unless rule['score_delta'].is_a?(Integer) && rule['score_delta'] >= 0
    raise ArgumentError, 'Score rules cannot force a quality' if rule['forced_outcome'].present?
  end

  def self.validate_operator!(operator, type)
    allowed = ['eq']
    allowed += ORDERED_OPERATORS if %w[number money].include?(type)
    allowed << 'in' if type == 'choice'
    raise ArgumentError, 'Operator is incompatible with field type' unless allowed.include?(operator)
  end

  def self.normalize_comparison_value(type, value, field, currency, operator)
    case type
    when 'money' then normalize_money_value(value, currency)
    when 'number' then normalize_number_value(value)
    when 'boolean' then normalize_boolean_value(value)
    when 'choice' then normalize_choice_value(value, field, operator)
    else normalize_text_value(value)
    end
  end

  def self.normalize_money_value(value, currency)
    raise ArgumentError, 'Rule money must use the field currency' unless value.is_a?(Hash) && value['currency'] == currency

    minor = AiLeadEmployee::OfferMoney.parse(value['amount'], currency)
    raise ArgumentError, 'A money comparison needs an amount' unless minor

    { 'amount' => AiLeadEmployee::OfferMoney.format(minor, currency), 'currency' => currency }
  end

  def self.normalize_number_value(value)
    raise ArgumentError, 'A numeric comparison needs a finite number' unless value.is_a?(Numeric) && value.finite?

    value
  end

  def self.normalize_boolean_value(value)
    raise ArgumentError, 'A boolean comparison needs true or false' unless [true, false].include?(value)

    value
  end

  def self.normalize_choice_value(value, field, operator)
    values = operator == 'in' ? value : [value]
    unless values.is_a?(Array) && values.any? && (values - field.fetch('options')).empty?
      raise ArgumentError, 'Comparison must use configured choices'
    end

    value
  end

  def self.normalize_text_value(value)
    raise ArgumentError, 'A text comparison needs text' unless value.is_a?(String) && value.present?

    value
  end

  private_class_method :validate_score_effect!, :validate_operator!, :normalize_comparison_value,
                       :normalize_money_value, :normalize_number_value, :normalize_boolean_value,
                       :normalize_choice_value, :normalize_text_value

  def initialize(offer:, snapshot:)
    @offer = offer
    @snapshot = snapshot
  end

  def matches
    @matches ||= @offer.configuration.fetch('rules', []).select { |rule| rule['enabled'] && matches?(rule) }.sort_by { |rule| rule['priority'] }
  end

  def score_delta
    matches.select { |rule| rule['kind'] == 'score_rule' }.sum { |rule| rule['score_delta'] }
  end

  def excluded?
    matches.any? { |rule| rule['kind'] == 'hard_rule' }
  end

  def reasons
    matches.map do |rule|
      effect = case rule['kind']
               when 'score_rule' then "+#{rule['score_delta']}"
               when 'requirement' then 'Requirement met'
               else 'Unqualified'
               end
      fact = @snapshot.fetch(rule['field'])
      "#{rule['field'].humanize}: #{rule['operator']} #{rule['value']} → #{effect} (evidence #{fact['evidence_id']})"
    end
  end

  def requirements
    @offer.configuration.fetch('rules', []).select { |rule| rule['enabled'] && rule['kind'] == 'requirement' }
  end

  def requirement_state(rule)
    fact = @snapshot[rule['field']]
    return :missing unless fact && fact['polarity'] != 'unknown' && fact['asserted'] != false
    return :missing if comparison_rule?(rule) && comparison_values(rule, fact).first.nil?

    matches?(rule) ? :met : :not_met
  end

  private

  def comparison_rule?(rule)
    POLARITY_OPERATORS.exclude?(rule['operator'])
  end

  def matches?(rule)
    fact = @snapshot[rule['field']]
    return false unless fact && fact['polarity'] != 'unknown'
    return fact['polarity'] == rule['operator'] if %w[positive negative].include?(rule['operator'])
    return true if rule['operator'] == 'known'

    actual, expected = comparison_values(rule, fact)
    return false if actual.nil?

    compare_values(rule['operator'], actual, expected)
  end

  def compare_values(operator, actual, expected)
    case operator
    when 'eq' then actual == expected
    when 'in' then expected.include?(actual)
    when *ORDERED_OPERATORS then ordered_match?(operator, actual, expected)
    end
  end

  def ordered_match?(operator, actual, expected)
    return false unless actual.is_a?(Numeric)

    case operator
    when 'lt' then actual < expected
    when 'lte' then actual <= expected
    when 'gt' then actual > expected
    when 'gte' then actual >= expected
    end
  end

  def comparison_values(rule, fact)
    expected = rule['value']
    if expected.is_a?(Hash)
      return [nil, nil] unless fact['polarity'] == 'positive' && fact['currency'] == expected['currency']

      [fact['amount_minor'], AiLeadEmployee::OfferMoney.parse(expected['amount'], expected['currency'])]
    else
      [fact.fetch('typed_value', fact['value']), expected]
    end
  end
end
