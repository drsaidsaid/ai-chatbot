# frozen_string_literal: true

class AiLeadEmployee::AiProvider::AccountingUncertainFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:accounting_uncertain])
  end
end
