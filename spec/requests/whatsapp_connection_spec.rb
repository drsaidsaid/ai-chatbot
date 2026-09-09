require 'rails_helper'

RSpec.describe 'WhatsApp connection', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:headers) { admin.create_new_auth_token }
  let(:configuration) do
    {
      name: 'Business WhatsApp',
      channel: {
        type: 'whatsapp', provider: 'whatsapp_cloud', phone_number: '+255700000003',
        provider_config: {
          api_key: 'r03-access-secret', app_secret: 'r03-signing-secret',
          phone_number_id: '3003', business_account_id: '9003'
        }
      }
    }
  end

  before do
    stub_request(:get, %r{https://graph.facebook.com/[^/]+/9003/message_templates})
      .to_return(status: 200, body: { data: [] }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, %r{https://graph.facebook.com/[^/]+/9003/phone_numbers})
      .to_return(status: 200, body: { data: [{ id: '3003' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, %r{https://graph.facebook.com/[^/]+/3003})
      .to_return(status: 200, body: { id: '3003', status: 'CONNECTED', code_verification_status: 'VERIFIED', platform_type: 'CLOUD_API' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, %r{https://graph.facebook.com/[^/]+/9003\?})
      .to_return(status: 200, body: { id: '9003', name: 'Synthetic business' }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, %r{https://graph.facebook.com/[^/]+/(9003/subscribed_apps|3003)})
      .to_return(status: 200, body: { success: true }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'saves usable encrypted credentials without returning stored secrets to the administrator' do
    post "/api/v1/accounts/#{account.id}/inboxes", params: configuration, headers: headers, as: :json

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('r03-access-secret', 'r03-signing-secret')
    inbox_id = response.parsed_body.fetch('id')
    channel = account.inboxes.find(inbox_id).channel.reload
    expect(channel.provider_config).to include('api_key' => 'r03-access-secret', 'app_secret' => 'r03-signing-secret')
    raw = Channel::Whatsapp.connection.select_one("SELECT * FROM channel_whatsapp WHERE id = #{channel.id}")
    expect(raw.to_json).not_to include('r03-access-secret', 'r03-signing-secret')

    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox_id}", headers: headers
    expect(response.parsed_body.fetch('provider_config')).to include('api_key_configured' => true, 'app_secret_configured' => true)
    expect(response.body).not_to include('r03-access-secret', 'r03-signing-secret', channel.provider_config.fetch('webhook_verify_token'))
  end

  it 'keeps one Cloud connection per Business Account even when another number is submitted' do
    post "/api/v1/accounts/#{account.id}/inboxes", params: configuration, headers: headers, as: :json
    expect(response).to have_http_status(:success)
    configuration[:channel][:phone_number] = '+255700000004'

    expect do
      post "/api/v1/accounts/#{account.id}/inboxes", params: configuration, headers: headers, as: :json
    end.not_to change(Channel::Whatsapp, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'configures and reloads direct setup with saved health and retains credentials on a nonsecret update' do
    path = "/api/v1/accounts/#{account.id}/whatsapp_connection"
    get path, headers: headers
    expect(response).to have_http_status(:success)
    expect(response.parsed_body['status']).to eq('not_connected')

    values = configuration[:channel][:provider_config].merge(name: 'Business WhatsApp', phone_number: '+255700000003')
    patch path, params: values, headers: headers, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'awaiting_message', 'api_key_configured' => true, 'app_secret_configured' => true)
    expect(response.parsed_body.values_at('health_checked_at', 'webhook_registered_at')).to all(be_present)
    expect(response.body).not_to include('r03-access-secret', 'r03-signing-secret')

    patch path, params: { name: 'Renamed WhatsApp' }, headers: headers, as: :json
    get path, headers: headers
    expect(response.parsed_body).to include('name' => 'Renamed WhatsApp', 'status' => 'awaiting_message', 'api_key_configured' => true)
  end

  it 'persists a safe connection failure without reflecting provider secrets' do
    path = "/api/v1/accounts/#{account.id}/whatsapp_connection"
    values = configuration[:channel][:provider_config].merge(name: 'Business WhatsApp', phone_number: '+255700000003')
    patch path, params: values, headers: headers, as: :json
    stub_request(:get, %r{https://graph.facebook.com/[^/]+/3003})
      .to_return(status: 401, body: { error: { code: 190, message: 'r03-access-secret r03-signing-secret' } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    post "#{path}/health_check", headers: headers
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'needs_attention', 'health_error_code' => 'authorization')
    expect(response.body).not_to include('r03-access-secret', 'r03-signing-secret')
    get path, headers: headers
    expect(response.parsed_body['health_error_code']).to eq('authorization')
  end

  it 'keeps an unsigned configuration incomplete and denies team member connection access' do
    post "/api/v1/accounts/#{account.id}/inboxes", params: configuration, headers: headers, as: :json
    channel = account.whatsapp_channels.first
    channel.provider_config = channel.provider_config.merge('app_secret' => nil)
    channel.save!
    path = "/api/v1/accounts/#{account.id}/whatsapp_connection"
    get path, headers: headers
    expect(response.parsed_body['status']).to eq('incomplete')

    member = create(:user, account: account, role: :agent)
    [[:get, path], [:patch, path], [:post, "#{path}/health_check"], [:post, "#{path}/retry_receiving"]].each do |method, url|
      public_send(method, url, headers: member.create_new_auth_token, as: :json)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'shows unexpanded receipts as pending and lets the administrator recover a queue outage' do
    post "/api/v1/accounts/#{account.id}/inboxes", params: configuration, headers: headers, as: :json
    channel = account.whatsapp_channels.first
    receipt = Whatsapp::WebhookReceipt.create!(raw_body: '{}', body_digest: 'queue-outage', error_code: 'queue_unavailable',
                                               verified_routes: [{ channel_id: channel.id, account_id: account.id, inbox_id: channel.inbox.id }])
    path = "/api/v1/accounts/#{account.id}/whatsapp_connection"

    get path, headers: headers
    expect(response.parsed_body).to include('pending_count' => 1, 'receiving_error_code' => 'queue_unavailable', 'status' => 'needs_attention')
    expect { post "#{path}/retry_receiving", headers: headers }.to have_enqueued_job(Webhooks::WhatsappEventsJob).with(receipt.id)
  end

  it 'requires affirmative provider health and sanitizes historical health errors' do
    path = "/api/v1/accounts/#{account.id}/whatsapp_connection"
    values = configuration[:channel][:provider_config].merge(name: 'Business WhatsApp', phone_number: '+255700000003')
    patch path, params: values, headers: headers, as: :json
    channel = account.whatsapp_channels.first
    channel.update!(phone_number_health: { 'status' => 'UNKNOWN' })
    get path, headers: headers
    expect(response.parsed_body['status']).to eq('check_required')

    channel.update!(phone_number_health_error: 'historical r03-access-secret')
    get path, headers: headers
    expect(response.parsed_body).to include('status' => 'needs_attention', 'health_error_code' => 'provider_unavailable')
    expect(response.body).not_to include('r03-access-secret')
  end

  it 'does not reflect credentials returned by a provider health response' do
    post "/api/v1/accounts/#{account.id}/inboxes", params: configuration, headers: headers, as: :json
    inbox = account.whatsapp_channels.first.inbox
    stub_request(:get, %r{https://graph.facebook.com/[^/]+/3003})
      .to_return(status: 200, body: {
        id: '3003', status: 'CONNECTED', webhook_configuration: {
          phone_number: 'https://example.test/callback', verify_token: 'r03-access-secret'
        }
      }.to_json, headers: { 'Content-Type' => 'application/json' })
    get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/health", headers: headers

    expect(response).to have_http_status(:success)
    expect(response.body).not_to include('r03-access-secret')
    expect(response.parsed_body['webhook_configuration']).to eq('phone_number' => 'https://example.test/callback')
  end
end
