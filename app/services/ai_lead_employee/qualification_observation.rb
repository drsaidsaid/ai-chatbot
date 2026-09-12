# frozen_string_literal: true

class AiLeadEmployee::QualificationObservation
  def initialize(signal:, value:, budget_basis:)
    @signal = signal
    @display_value = value
    @budget_basis = budget_basis
  end

  def value
    observation = {
      'value' => display_value,
      'polarity' => AiLeadEmployee::QualificationEvidenceExtractor::POLARITY_FOR_VALUE.fetch(display_value, 'positive')
    }
    if signal == 'budget' && observation['polarity'] == 'positive'
      observation.merge!(AiLeadEmployee::QualificationAmountParser.parse(display_value) || {})
    end
    assign_typed_value(observation)
    observation['basis'] = budget_basis if signal == 'budget' && observation['polarity'] == 'positive' && budget_basis
    observation
  end

  private

  attr_reader :signal, :display_value, :budget_basis

  def assign_typed_value(observation)
    observation['typed_value'] = display_value.to_i if signal == 'lead_volume' && observation['polarity'] == 'positive'
    observation['typed_value'] = observation['polarity'] == 'positive' if signal == 'decision_authority' && observation['polarity'] != 'unknown'
  end
end
