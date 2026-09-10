# frozen_string_literal: true

module AiLeadEmployee::AiProvider
  FAILURE_CLASSES = {
    timeout: 'timeout',
    authentication: 'authentication_failure',
    insufficient_credits: 'insufficient_credits',
    rate_limit: 'rate_limit',
    invalid_response: 'invalid_response',
    safety_refusal: 'safety_refusal',
    transport: 'transport_failure',
    disabled: 'provider_disabled',
    usage_limit: 'usage_limit_exhausted',
    input_limit: 'input_limit_exceeded',
    output_limit: 'output_limit_exceeded',
    configuration_changed: 'provider_configuration_changed',
    admission_unavailable: 'provider_admission_unavailable',
    accounting_uncertain: 'provider_accounting_uncertain'
  }.freeze
end
