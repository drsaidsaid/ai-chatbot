# frozen_string_literal: true

class AiLeadEmployee::AiProvider::DisabledFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:disabled])
  end
end
