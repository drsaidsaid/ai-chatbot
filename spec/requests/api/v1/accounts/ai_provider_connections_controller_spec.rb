# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Managed AI service API', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_admin) { create(:user, account: other_account, role: :administrator) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/ai_provider_connection" }

  it 'shows an account admin only managed-service readiness and account-isolated usage', :aggregate_failures do
    connection = create(
      :ai_provider_connection,
      account: account,
      model: 'secret/model-route',
      api_key: 'sk-or-client-must-not-infer',
      daily_request_limit: 10,
      last_health_status: 'healthy',
      last_health_configuration_version: 1,
      last_health_response: {
        model: 'secret/model-route',
        reply_token_limit: 512,
        configuration_version: 1
      }
    )
    create_usage(connection: connection, cost_available: false)
    other_connection = create(:ai_provider_connection, account: other_account, daily_request_limit: 20)
    create_usage(connection: other_connection, cost_available: true, cost_usd: 9)

    get endpoint, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'managed_service' => true,
      'service_status' => 'active',
      'readiness_status' => 'healthy',
      'requests_used_today' => 1,
      'requests_remaining_today' => 9,
      'automation_allowed' => true
    )
    expect(response.parsed_body.keys).not_to include(
      'provider', 'model', 'has_credentials', 'configuration_version', 'reply_token_limit',
      'last_health_model', 'last_health_reply_token_limit', 'last_health_configuration_version',
      'last_health_failure_class', 'cost_usd_today', 'cost_data_complete'
    )
    expect(response.body).not_to include('secret/model-route', 'sk-or-client-must-not-infer', '9.0')
  end

  it 'does not let a team member infer whether managed AI is configured' do
    create(:ai_provider_connection, account: account)

    get endpoint, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.body).not_to include('managed_service', 'service_status', 'credentials')
  end

  it 'does not let another Business Account inspect managed AI state' do
    create(:ai_provider_connection, account: account)

    get endpoint, headers: other_admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.body).not_to include('managed_service', 'service_status', 'credentials')
  end

  it 'rejects stale client configuration, disable and health-check requests', :aggregate_failures do
    create(:ai_provider_connection, account: account)
    headers = admin.create_new_auth_token

    patch endpoint, headers: headers, params: { model: 'attacker/model', api_key: 'attacker-key' }, as: :json
    expect(response).to have_http_status(:not_found)

    delete endpoint, headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    post "#{endpoint}/health_check", headers: headers, as: :json
    expect(response).to have_http_status(:not_found)

    connection = account.ai_provider_connection.reload
    expect(connection.model).not_to eq('attacker/model')
    expect(connection.api_key).not_to eq('attacker-key')
    expect(connection).to be_active
  end

  it 'does not treat a Business Account admin or Team Member as a Platform Operator', :aggregate_failures do
    platform_endpoint = "/platform/api/v1/accounts/#{account.id}/ai_provider_connection"

    [admin, agent].each do |user|
      patch platform_endpoint,
            headers: user.create_new_auth_token,
            params: { model: 'attacker/model', api_key: 'attacker-key' },
            as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('model', 'credentials', 'provider')
    end
  end

  private

  def create_usage(connection:, cost_available:, cost_usd: nil)
    AiLeadEmployee::AiProviderUsage.create!(
      account: connection.account,
      ai_provider_connection: connection,
      configuration_version: connection.configuration_version,
      purpose: 'answer',
      period_on: Time.current.utc.to_date,
      status: 'completed',
      requested_output_tokens: connection.reply_token_limit,
      started_at: Time.current,
      completed_at: Time.current,
      cost_available: cost_available,
      cost_usd: cost_usd
    )
  end
end
