# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform Pilot Authorizations API', type: :request do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700000001') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active)
  end
  let(:platform_app) { create(:platform_app, pilot_operations_enabled: true) }
  let(:headers) { { api_access_token: platform_app.access_token.token } }
  let(:endpoint) { "/platform/api/v1/accounts/#{account.id}/pilot_authorizations" }

  before do
    clean_committed_fixtures
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
    create(:ai_provider_connection, account: account, api_key: 'sk-or-pilot-test')
  end

  after { clean_committed_fixtures }

  it 'requires the dedicated pilot permission even for an account-permitted Platform App' do
    platform_app.update!(pilot_operations_enabled: false)

    post endpoint, headers: headers, params: activation_params, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(AiLeadEmployee::PilotAuthorization.count).to eq(0)
  end

  it 'activates exact scope only after verifying the current provider key limit and never returns credentials or evidence hashes' do
    stub_request(:get, 'https://openrouter.ai/api/v1/key')
      .with(headers: { 'Authorization' => 'Bearer sk-or-pilot-test' })
      .to_return(status: 200, body: {
        data: { label: 'pilot-key', limit: 1.0, limit_remaining: 0.75, limit_reset: nil,
                expires_at: 1.day.from_now.iso8601 }
      }.to_json, headers: { 'content-type' => 'application/json' })

    post endpoint, headers: headers, params: activation_params, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'account_id' => account.id, 'conversation_id' => conversation.id, 'contact_id' => contact.id,
      'status' => 'active', 'max_attempts' => 3, 'max_spend_usd' => '1.0', 'provider_limit_usd' => '0.75'
    )
    expect(response.body).not_to include('sk-or-pilot-test', 'key_fingerprint', 'verification_digest')
    expect(AiLeadEmployee::PilotAuthorization.sole.provider_limit_evidence).to include(
      'kind' => 'openrouter_key_limit', 'source' => 'openrouter_current_key'
    )
  end

  it 'requires a nonempty external owner approval reference' do
    params = activation_params.except(:external_owner_approval_reference)
    post endpoint, headers: headers, params: params, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(AiLeadEmployee::PilotAuthorization.count).to eq(0)
  end

  def activation_params
    { conversation_id: conversation.id, max_attempts: 3, max_spend_usd: 1.0, expires_at: 1.hour.from_now.iso8601,
      external_owner_approval_reference: 'owner-approval-r17-test' }
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
