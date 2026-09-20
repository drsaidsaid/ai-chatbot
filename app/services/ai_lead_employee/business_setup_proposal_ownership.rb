# frozen_string_literal: true

class AiLeadEmployee::BusinessSetupProposalOwnership
  def self.remove_unchanged_fields!(configuration, previous_proposal)
    ownership = previous_proposal.fetch('source_ownership', {})
    protected_keys = group_fields(configuration.fetch('requirement_groups', []))
    retired_keys = unchanged_keys(configuration, ownership, previous_proposal) - protected_keys
    configuration['questions'] = Array(configuration['questions']).reject { |question| retired_keys.include?(question['key']) }
    configuration['rules'] = Array(configuration['rules']).reject { |rule| retired_keys.include?(rule['field']) }
  end

  def self.unchanged_keys(configuration, ownership, previous_proposal)
    legacy_keys = Array(ownership['question_keys']).presence || Array(previous_proposal['generated_question_keys'])
    questions = owned_groups(ownership, 'questions', previous_proposal.fetch('configuration', {}), legacy_keys, 'key')
    rules = owned_groups(ownership, 'rules', previous_proposal.fetch('configuration', {}), legacy_keys, 'field')
    (questions.keys & rules.keys).select do |key|
      source_owned_field_unchanged?(configuration, key, questions[key], rules[key])
    end
  end
  private_class_method :unchanged_keys

  def self.record!(ownership:, configuration:, keys:)
    ownership['questions'] = grouped_values(configuration['questions'], 'key', keys)
    ownership['rules'] = grouped_values(configuration['rules'], 'field', keys)
  end

  def self.source_owned_field_unchanged?(configuration, key, questions, rules)
    field_values(configuration['questions'], 'key', key) == questions &&
      field_values(configuration['rules'], 'field', key) == rules
  end
  private_class_method :source_owned_field_unchanged?

  def self.owned_groups(ownership, type, fallback_configuration, legacy_keys, key)
    return normalize_groups(ownership[type]) if ownership.key?(type)

    grouped_values(fallback_configuration[type], key, legacy_keys)
  end
  private_class_method :owned_groups

  def self.normalize_groups(values)
    values.to_h.transform_values { |value| value.is_a?(Array) ? value : [value] }
  end
  private_class_method :normalize_groups

  def self.grouped_values(values, key, keys)
    Array(values).select { |value| keys.include?(value[key]) }.group_by { |value| value[key] }.deep_dup
  end
  private_class_method :grouped_values

  def self.field_values(values, key, field)
    Array(values).select { |value| value[key] == field }
  end
  private_class_method :field_values

  def self.group_fields(nodes)
    Array(nodes).flat_map do |node|
      node['field'] || group_fields(node['all'] || node['any'])
    end.compact.uniq
  end
  private_class_method :group_fields
end
