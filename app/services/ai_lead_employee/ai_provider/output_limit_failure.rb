# frozen_string_literal: true

class AiLeadEmployee::AiProvider::OutputLimitFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:output_limit])
  end
end
