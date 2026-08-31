# frozen_string_literal: true

class AiLeadEmployee::AiProvider::InsufficientCreditsFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:insufficient_credits])
  end
end
