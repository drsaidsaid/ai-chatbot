# frozen_string_literal: true

class AiLeadEmployee::BusinessSetupProposalOwnership
  def self.remove_unchanged_fields!(configuration, ownership)
    questions = ownership.fetch('questions', {})
    rules = ownership.fetch('rules', {})
    retired_keys = (questions.keys & rules.keys).select do |key|
      source_owned_field_unchanged?(configuration, key, questions[key], rules[key])
    end
    configuration['questions'] = Array(configuration['questions']).reject { |question| retired_keys.include?(question['key']) }
    configuration['rules'] = Array(configuration['rules']).reject { |rule| retired_keys.include?(rule['field']) }
  end

  def self.record!(ownership:, configuration:, keys:)
    ownership['questions'] = owned_values(configuration['questions'], 'key', keys)
    ownership['rules'] = owned_values(configuration['rules'], 'field', keys)
  end

  def self.source_owned_field_unchanged?(configuration, key, question, rule)
    Array(configuration['questions']).find { |item| item['key'] == key } == question &&
      Array(configuration['rules']).find { |item| item['field'] == key } == rule
  end
  private_class_method :source_owned_field_unchanged?

  def self.owned_values(values, key, keys)
    Array(values).filter_map { |value| [value[key], value.deep_dup] if keys.include?(value[key]) }.to_h
  end
  private_class_method :owned_values
end
