# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI provider connection API', type: :request do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_admin) { create(:user, account: other_account, role: :administrator) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/ai_provider_connection" }

  before { clean_committed_fixtures }
  after { clean_committed_fixtures }

  it 'lets an admin configure and rotate one encrypted provider connection without returning the raw key', :aggregate_failures do
    require_configured_encryption!

    patch endpoint,
          headers: admin.create_new_auth_token,
          params: {
            provider: 'openrouter',
            model: 'openai/gpt-4.1-mini',
            reply_token_limit: 512,
            daily_request_limit: 25,
            api_key: 'sk-or-original-secret'
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'provider' => 'openrouter',
      'model' => 'openai/gpt-4.1-mini',
      'status' => 'active',
      'has_credentials' => true,
      'readiness_status' => 'not_checked',
      'reply_token_limit' => 512,
      'daily_request_limit' => 25,
      'requests_used_today' => 0,
      'cost_usd_today' => nil,
      'cost_data_complete' => true
    )
    expect(response.parsed_body).not_to have_key('api_key')

    connection = account.reload.ai_provider_connection
    expect(connection.api_key).to eq('sk-or-original-secret')
    expect(connection.read_attribute_before_type_cast(:api_key).to_s).not_to include('sk-or-original-secret') if Chatwoot.encryption_configured?

    patch endpoint,
          headers: admin.create_new_auth_token,
          params: {
            provider: 'openrouter',
            model: 'openai/gpt-5.2',
            reply_token_limit: 256,
            daily_request_limit: 10,
            api_key: 'sk-or-rotated-secret'
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(connection.reload.api_key).to eq('sk-or-rotated-secret')
    expect(connection.model).to eq('openai/gpt-5.2')
    expect(connection.reply_token_limit).to eq(256)
    expect(connection.daily_request_limit).to eq(10)
    expect(connection.configuration_version).to eq(2)
    expect(connection.last_health_status).to be_nil
  end

  it 'lets an admin disable the provider connection and clears usable credentials', :aggregate_failures do
    require_configured_encryption!

    connection = create(:ai_provider_connection, account: account, api_key: 'sk-or-disable-me')

    delete endpoint, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'disabled', 'has_credentials' => false)
    expect(connection.reload).to be_disabled
    expect(connection.api_key).to be_nil
    expect(connection.configuration_version).to eq(2)
    expect(connection.last_health_status).to be_nil

    delete endpoint, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(connection.reload.configuration_version).to eq(2)

    post "#{endpoint}/health_check", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('status' => 'failed', 'failure_class' => 'provider_disabled')
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

  it 'checks readiness at the configured reply budget and reports provider-supplied usage without exposing credentials', :aggregate_failures do
    require_configured_encryption!

    create(:ai_provider_connection, account: account, api_key: 'sk-or-health', reply_token_limit: 512, daily_request_limit: 10)
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .with do |request|
        expect(JSON.parse(request.body)).to include('max_tokens' => 512)
      end
      .to_return(
        status: 200,
        body: {
          id: 'chatcmpl-health',
          model: 'openai/gpt-4.1-mini',
          choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }],
          usage: { prompt_tokens: 8, completion_tokens: 2, total_tokens: 10, cost: 0.00125 }
        }.to_json,
        headers: { 'content-type' => 'application/json' }
      )

    post "#{endpoint}/health_check", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'healthy')
    expect(response.parsed_body.to_json).not_to include('sk-or-health')
    expect(account.ai_provider_connection.reload.last_health_status).to eq('healthy')

    get endpoint, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include(
      'readiness_status' => 'healthy',
      'last_health_model' => 'openai/gpt-4.1-mini',
      'last_health_reply_token_limit' => 512,
      'last_health_configuration_version' => 1,
      'requests_used_today' => 1,
      'cost_usd_today' => '0.00125',
      'cost_data_complete' => true
    )
  end

  it 'stops new provider work when the daily request allowance is exhausted', :aggregate_failures do
    require_configured_encryption!

    create(:ai_provider_connection, account: account, daily_request_limit: 1)
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
              .to_return(
                status: 200,
                body: {
                  id: 'chatcmpl-only-allowed-attempt',
                  choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }]
                }.to_json
              )

    post "#{endpoint}/health_check", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('status' => 'healthy')

    post "#{endpoint}/health_check", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('status' => 'failed', 'failure_class' => 'usage_limit_exhausted')
    expect(request).to have_been_requested.once

    get endpoint, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include(
      'readiness_status' => 'failed',
      'last_health_failure_class' => 'usage_limit_exhausted',
      'requests_used_today' => 1,
      'requests_remaining_today' => 0,
      'automation_allowed' => false,
      'automation_paused_reason' => 'usage_limit_exhausted'
    )
    expect(Time.iso8601(response.parsed_body.fetch('usage_resets_at'))).to eq(Time.current.utc.tomorrow.beginning_of_day)
    expect(response.parsed_body.fetch('usage_resets_at_label')).to be_present
  end

  it 'does not report ready when a tiny probe would pass but the configured reply budget has insufficient credits' do
    require_configured_encryption!

    create(:ai_provider_connection, account: account, reply_token_limit: 512, daily_request_limit: 10)
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
              .to_return do |provider_request|
      requested_tokens = JSON.parse(provider_request.body).fetch('max_tokens')
      if requested_tokens <= 8
        { status: 200, body: '{"choices":[{"message":{"content":"ok"}}]}' }
      else
        { status: 402, body: '{"error":{"message":"Only 49 tokens are affordable"}}' }
      end
    end

    post "#{endpoint}/health_check", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to include('status' => 'failed', 'failure_class' => 'insufficient_credits')
    expect(request).to have_been_requested.once

    get endpoint, headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include(
      'readiness_status' => 'failed',
      'last_health_failure_class' => 'insufficient_credits',
      'requests_used_today' => 1,
      'cost_usd_today' => nil,
      'cost_data_complete' => false
    )
  end

  it 'labels health and allowance times in the Business Account reporting timezone' do
    require_configured_encryption!

    account.update!(reporting_timezone: 'Nairobi')
    create(
      :ai_provider_connection,
      account: account,
      last_health_status: 'healthy',
      last_health_checked_at: Time.utc(2026, 9, 10, 12),
      last_health_configuration_version: 1,
      last_health_response: {
        model: 'openai/gpt-4.1-mini',
        reply_token_limit: 512,
        configuration_version: 1
      }
    )

    get endpoint, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'last_health_checked_at_label' => '2026-09-10 15:00 EAT',
      'reporting_timezone' => 'Nairobi'
    )
    expect(response.parsed_body.fetch('usage_resets_at_label')).to end_with('EAT')
  end

  def require_configured_encryption!
    skip('encryption keys missing; AI Provider Connections reject plaintext credentials') unless Chatwoot.encryption_configured?
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
