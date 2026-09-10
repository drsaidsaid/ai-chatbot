# frozen_string_literal: true

class AiLeadEmployee::AiProvider::ConfigurationChangedFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:configuration_changed])
  end
end
