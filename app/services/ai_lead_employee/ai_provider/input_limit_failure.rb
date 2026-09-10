# frozen_string_literal: true

class AiLeadEmployee::AiProvider::InputLimitFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:input_limit])
  end
end
