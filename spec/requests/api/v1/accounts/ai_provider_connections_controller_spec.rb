# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI provider connection API', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_admin) { create(:user, account: other_account, role: :administrator) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/ai_provider_connection" }

  it 'lets an admin configure and rotate one encrypted provider connection without returning the raw key', :aggregate_failures do
    require_configured_encryption!

    patch endpoint,
          headers: admin.create_new_auth_token,
          params: {
            provider: 'openrouter',
            model: 'openai/gpt-4.1-mini',
            api_key: 'sk-or-original-secret'
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'provider' => 'openrouter',
      'model' => 'openai/gpt-4.1-mini',
      'status' => 'active',
      'has_credentials' => true
    )
    expect(response.parsed_body).not_to have_key('api_key')

    connection = account.reload.ai_provider_connection
    expect(connection.api_key).to eq('sk-or-original-secret')
    expect(connection.read_attribute_before_type_cast(:api_key).to_s).not_to include('sk-or-original-secret') if Chatwoot.encryption_configured?

    patch endpoint,
          headers: admin.create_new_auth_token,
          params: { provider: 'openrouter', model: 'openai/gpt-5.2', api_key: 'sk-or-rotated-secret' },
          as: :json

    expect(response).to have_http_status(:success)
    expect(connection.reload.api_key).to eq('sk-or-rotated-secret')
    expect(connection.model).to eq('openai/gpt-5.2')
  end

  it 'lets an admin disable the provider connection and clears usable credentials', :aggregate_failures do
    require_configured_encryption!

    connection = create(:ai_provider_connection, account: account, api_key: 'sk-or-disable-me')

    delete endpoint, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'disabled', 'has_credentials' => false)
    expect(connection.reload).to be_disabled
    expect(connection.api_key).to be_nil
  end

  it 'does not let a team member view or infer whether credentials exist', :aggregate_failures do
    create(:ai_provider_connection, account: account) if Chatwoot.encryption_configured?

    get endpoint, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.to_json).not_to include('has_credentials')

    patch endpoint,
          headers: agent.create_new_auth_token,
          params: { provider: 'openrouter', model: 'openai/gpt-4.1-mini', api_key: 'sk-or-agent' },
          as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{endpoint}/health_check", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'keeps provider connections isolated by Business Account', :aggregate_failures do
    create(:ai_provider_connection, account: account) if Chatwoot.encryption_configured?

    get endpoint, headers: other_admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch endpoint,
          headers: other_admin.create_new_auth_token,
          params: { provider: 'openrouter', model: 'openai/gpt-4.1-mini', api_key: 'sk-or-cross-tenant' },
          as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{endpoint}/health_check", headers: other_admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    delete endpoint, headers: other_admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'health-checks the configured provider without exposing credentials', :aggregate_failures do
    require_configured_encryption!

    create(:ai_provider_connection, account: account, api_key: 'sk-or-health')
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .to_return(
        status: 200,
        body: {
          id: 'chatcmpl-health',
          choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }]
        }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    post "#{endpoint}/health_check", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'healthy')
    expect(response.parsed_body.to_json).not_to include('sk-or-health')
    expect(account.ai_provider_connection.reload.last_health_status).to eq('healthy')
  end

  def require_configured_encryption!
    skip('encryption keys missing; AI Provider Connections reject plaintext credentials') unless Chatwoot.encryption_configured?
  end
end
