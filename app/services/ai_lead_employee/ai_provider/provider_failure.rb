# frozen_string_literal: true

class AiLeadEmployee::AiProvider::ProviderFailure < StandardError
  attr_reader :failure_class

  def initialize(message = nil, failure_class:)
    @failure_class = failure_class
    super(message.presence || failure_class)
  end
end
