# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform AI Provider Connections API', type: :request do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:platform_app) { create(:platform_app) }
  let(:headers) { { api_access_token: platform_app.access_token.token } }
  let(:endpoint) { "/platform/api/v1/accounts/#{account.id}/ai_provider_connection" }

  before { clean_committed_fixtures }
  after { clean_committed_fixtures }

  it 'lets an authorised Platform Operator configure an account-attributed encrypted connection', :aggregate_failures do
    require_configured_encryption!
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)

    patch endpoint,
          headers: headers,
          params: {
            provider: 'openrouter',
            model: 'openai/gpt-4.1-mini',
            reply_token_limit: 512,
            daily_request_limit: 25,
            api_key: 'sk-or-platform-secret'
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'provider' => 'openrouter',
      'model' => 'openai/gpt-4.1-mini',
      'status' => 'active',
      'has_credentials' => true,
      'configuration_version' => 1
    )
    expect(response.body).not_to include('sk-or-platform-secret')

    connection = account.reload.ai_provider_connection
    expect(connection.account_id).to eq(account.id)
    expect(connection.api_key).to eq('sk-or-platform-secret')
    expect(connection.read_attribute_before_type_cast(:api_key).to_s).not_to include('sk-or-platform-secret')
  end

  it 'uses indistinguishable authorization failures for unpermitted accounts with and without a connection', :aggregate_failures do
    create(:ai_provider_connection, account: account)

    get endpoint, headers: headers, as: :json
    existing_response = response.parsed_body
    existing_status = response.status

    get "/platform/api/v1/accounts/#{other_account.id}/ai_provider_connection", headers: headers, as: :json

    expect(existing_status).to eq(401)
    expect(response.status).to eq(existing_status)
    expect(response.parsed_body).to eq(existing_response)
    expect(response.body).not_to include('credentials', 'model', 'provider')
  end

  it 'reports usage and unknown provider cost separately for each permitted Account', :aggregate_failures do
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
    create(:platform_app_permissible, platform_app: platform_app, permissible: other_account)
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    other_connection = create(:ai_provider_connection, account: other_account, daily_request_limit: 20)
    create_usage(connection: connection, cost_available: false)
    create_usage(connection: other_connection, cost_available: true, cost_usd: 7.5)

    get endpoint, headers: headers, as: :json

    expect(response.parsed_body).to include(
      'requests_used_today' => 1,
      'requests_remaining_today' => 9,
      'cost_usd_today' => nil,
      'cost_data_complete' => false
    )

    get "/platform/api/v1/accounts/#{other_account.id}/ai_provider_connection", headers: headers, as: :json

    expect(response.parsed_body).to include(
      'requests_used_today' => 1,
      'requests_remaining_today' => 19,
      'cost_usd_today' => '7.5',
      'cost_data_complete' => true
    )
  end

  it 'health-checks and disables only through the platform boundary without returning credentials', :aggregate_failures do
    require_configured_encryption!
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
    connection = create(:ai_provider_connection, account: account, api_key: 'sk-or-health', daily_request_limit: 10)
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .to_return(
        status: 200,
        body: {
          id: 'chatcmpl-health',
          choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }],
          usage: { total_tokens: 10, cost: 0.00125 }
        }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    post "#{endpoint}/health_check", headers: headers, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'healthy')
    expect(response.body).not_to include('sk-or-health')

    delete endpoint, headers: headers, as: :json
    expect(response).to have_http_status(:success)
    expect(connection.reload).to be_disabled
    expect(connection.api_key).to be_nil
  end

  private

  def require_configured_encryption!
    skip('encryption keys missing; AI Provider Connections reject plaintext credentials') unless Chatwoot.encryption_configured?
  end

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

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
