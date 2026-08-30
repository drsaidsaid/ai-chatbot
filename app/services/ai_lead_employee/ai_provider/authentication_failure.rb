# frozen_string_literal: true

class AiLeadEmployee::AiProvider::AuthenticationFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:authentication])
  end
end
