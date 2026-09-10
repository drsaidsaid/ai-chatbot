# frozen_string_literal: true

class AiLeadEmployee::AiProvider::AdmissionUnavailableFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:admission_unavailable])
  end
end
