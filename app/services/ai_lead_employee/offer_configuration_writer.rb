# frozen_string_literal: true

class AiLeadEmployee::OfferConfigurationWriter
  class Conflict < StandardError; end

  REQUIRED_QUESTION_FIELDS = %w[key meaning prompt].freeze
  QUESTION_TYPES = %w[text boolean number money choice].freeze
  QUESTION_PURPOSES = %w[fit readiness action_eligibility].freeze

  def initialize(offer:, attributes:)
    @offer = offer
    @attributes = attributes.deep_stringify_keys
  end

  def perform
    offer.class.transaction do
      offer.lock! if offer.persisted?
      raise Conflict, 'Configuration changed; reload before saving' if offer.persisted? && attributes['version'] != offer.configuration_version

      configuration = normalized_configuration
      validate_used_definitions!(configuration)
      persist_configuration!(configuration)
      offer
    end
  end

  def self.field_definition(question, currency)
    question.slice('key', 'meaning', 'answer_type', 'period', 'options').tap do |definition|
      definition['currency'] = currency if question['answer_type'] == 'money'
    end
  end

  private

  attr_reader :offer, :attributes

  def persist_configuration!(configuration)
    offer.assign_attributes(attributes.slice('name', 'currency', 'enabled'))
    offer.configuration = configuration
    offer.configuration_version += 1 if offer.persisted?
    offer.save!
    record_configuration_revision!
    offer.lead_qualifications.where(stale_at: nil).update_all(stale_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def record_configuration_revision!
    offer.configuration_revisions.create!(account: offer.account, version: offer.configuration_version, snapshot: offer.payload)
  end

  def normalized_configuration
    currency = attributes.fetch('currency')
    raise ArgumentError, 'Unsupported currency' unless AiLeadEmployee::OfferMoney::PRECISION.key?(currency)

    {
      'qualification_mode' => normalized_qualification_mode,
      'next_step' => normalized_next_step,
      'questions' => normalized_questions,
      'budget_ranges' => attributes.fetch('budget_ranges', []).map { |range| normalize_range(range, currency) },
      'rules' => AiLeadEmployee::OfferRules.normalize(attributes.fetch('rules', []), questions: normalized_questions, currency: currency),
      'score_weights' => normalized_weights,
      'score_thresholds' => normalized_thresholds
    }
  end

  def normalized_questions
    questions = attributes.fetch('questions')
    raise ArgumentError, 'Questions must be a list' unless questions.is_a?(Array)
    raise ArgumentError, 'Question keys must be unique' unless questions.pluck('key').uniq.length == questions.length

    questions.each { |question| validate_question!(question) }
    questions.map do |question|
      question.slice('key', 'meaning', 'answer_type', 'prompt', 'position', 'enabled', 'required', 'options', 'period', 'purpose')
              .merge('purpose' => question['purpose'].presence || 'fit')
    end
  end

  def validate_question!(question)
    validate_question_definition!(question)
    validate_choices!(question['options']) if question['answer_type'] == 'choice'
    raise ArgumentError, 'Invalid question position' unless question['position'].is_a?(Integer) && question['position'] >= 0
    raise ArgumentError, 'Unsupported question purpose' unless QUESTION_PURPOSES.include?(question['purpose'].presence || 'fit')
  end

  def validate_question_definition!(question)
    raise ArgumentError, 'A question needs a stable key, meaning and prompt' if REQUIRED_QUESTION_FIELDS.any? { |key| question[key].blank? }
    raise ArgumentError, 'Unsupported field type' unless QUESTION_TYPES.include?(question['answer_type'])

    builtin_type = AiLeadEmployee::OfferRules::BUILTIN_TYPES[question['key']]
    raise ArgumentError, 'Built-in field meaning and type are reserved' if builtin_type && builtin_type != question['answer_type']
  end

  def validate_choices!(options)
    return if options.is_a?(Array) && options.any? && options.uniq == options && options.all? { |option| option.is_a?(String) && option.present? }

    raise ArgumentError, 'Choices must be unique nonempty text values'
  end

  def normalize_range(range, currency)
    minimum = AiLeadEmployee::OfferMoney.parse(range['minimum'], currency)
    maximum = AiLeadEmployee::OfferMoney.parse(range['maximum'], currency)
    raise ArgumentError, 'Maximum must be at least the minimum' if minimum && maximum && minimum > maximum

    range.slice('label', 'enabled', 'position').merge('minimum_minor' => minimum, 'maximum_minor' => maximum)
  end

  def validate_used_definitions!(configuration)
    return unless offer.persisted?

    questions = configuration.fetch('questions').index_by { |question| question['key'] }
    QualificationEvidence.where(offer: offer).find_each do |evidence|
      previous = evidence.value['field_definition']
      next unless previous

      question = questions[evidence.field_key]
      if previous['answer_type'] == 'money' && previous['currency'] != attributes['currency']
        raise ArgumentError, 'Used money fields require a new Offer for a different currency'
      end
      next unless question

      proposed = self.class.field_definition(question, attributes['currency'])
      raise ArgumentError, 'Used field semantics cannot change; create a new field key' unless previous == proposed
    end
  end

  def normalized_weights
    weights = attributes.fetch('score_weights', {})
    fields = AiLeadEmployee::OfferRules::BUILTIN_TYPES.keys + normalized_questions.pluck('key')
    raise ArgumentError, 'Weights must name known fields and nonnegative integers' unless weights.is_a?(Hash) && weights.all? do |key, value|
      fields.include?(key) && value.is_a?(Integer) && value >= 0
    end

    weights
  end

  def normalized_qualification_mode
    mode = attributes['qualification_mode'].presence || inferred_qualification_mode
    raise ArgumentError, 'Unsupported qualification mode' unless AiLeadEmployee::Offer::QUALIFICATION_MODES.include?(mode)

    mode
  end

  def inferred_qualification_mode
    configured = attributes.fetch('questions', []).any? || attributes.fetch('rules', []).any? ||
                 attributes.fetch('score_weights', {}).any?
    configured ? 'enabled' : 'not_configured'
  end

  def normalized_next_step
    next_step = attributes.fetch('next_step', { 'kind' => 'answer_only' })
    raise ArgumentError, 'Next step must be an object' unless next_step.is_a?(Hash)
    raise ArgumentError, 'Unsupported next step' unless AiLeadEmployee::Offer::NEXT_STEP_KINDS.include?(next_step['kind'])

    next_step.slice('kind')
  end

  def normalized_thresholds
    thresholds = attributes.fetch('score_thresholds', { 'qualified' => 60, 'highly_qualified' => 80 })
    values = thresholds.values_at('qualified', 'highly_qualified')
    valid_values = values.all? do |value|
      value.is_a?(Integer) && value >= 0
    end
    raise ArgumentError, 'Thresholds must be ordered nonnegative integers' unless valid_values && values.last >= values.first

    thresholds.slice('qualified', 'highly_qualified')
  end
end
