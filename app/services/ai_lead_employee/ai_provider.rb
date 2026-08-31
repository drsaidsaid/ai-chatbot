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
    disabled: 'provider_disabled'
  }.freeze
end
