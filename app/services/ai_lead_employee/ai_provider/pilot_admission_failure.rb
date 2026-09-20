# frozen_string_literal: true

class AiLeadEmployee::AiProvider::PilotAdmissionFailure < AiLeadEmployee::AiProvider::ProviderFailure
  def initialize(message = nil)
    super(message, failure_class: AiLeadEmployee::AiProvider::FAILURE_CLASSES[:pilot_admission])
  end
end
