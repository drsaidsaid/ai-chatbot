# frozen_string_literal: true

class AiLeadEmployee::AiProvider::SafetyRefusalFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:safety_refusal])
  end
end
