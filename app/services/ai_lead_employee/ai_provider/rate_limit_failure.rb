# frozen_string_literal: true

class AiLeadEmployee::AiProvider::RateLimitFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:rate_limit])
  end
end
