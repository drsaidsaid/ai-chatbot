# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AiProviderConnection do
  it 'does not allow raw credentials to be stored without Active Record encryption' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(false)

    connection = build(:ai_provider_connection, api_key: 'sk-or-plaintext-risk')

    expect(connection).not_to be_valid
    expect(connection.errors[:api_key]).to include('cannot be stored until Active Record encryption is configured')
  end

  it 'keeps provider configuration, credential state and cost out of the Business Account payload' do
    connection = build(
      :ai_provider_connection,
      model: 'platform/private-model',
      api_key: 'sk-or-platform-private',
      last_health_failure_class: 'authentication_failure',
      last_health_response: { model: 'platform/private-model' }
    )
    allow(connection).to receive(:usage_payload).and_return(
      requests_used_today: 2,
      requests_remaining_today: 8,
      usage_resets_at: Time.current.utc.tomorrow.beginning_of_day,
      automation_allowed: true,
      automation_paused_reason: nil,
      cost_usd_today: 4.25,
      cost_data_complete: true,
      reporting_timezone: 'UTC',
      usage_resets_at_label: '2026-09-13 00:00 UTC'
    )

    payload = connection.managed_service_payload

    expect(payload).to include(managed_service: true, requests_used_today: 2)
    expect(payload.keys).not_to include(
      :provider, :model, :has_credentials, :last_health_failure_class,
      :last_health_model, :cost_usd_today, :cost_data_complete
    )
    expect(payload.to_json).not_to include('platform/private-model', 'sk-or-platform-private', 'authentication_failure', '4.25')
  end
end
