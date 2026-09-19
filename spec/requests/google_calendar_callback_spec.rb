# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Google Calendar OAuth callback', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:nonce) { SecureRandom.urlsafe_base64(32) }
  let!(:connection) do
    create(:google_calendar_connection, account: account, status: :disconnected, access_token: nil, refresh_token: nil,
                                        oauth_state_digest: Digest::SHA256.hexdigest(nonce),
                                        oauth_state_expires_at: 10.minutes.from_now)
  end
  let(:state) do
    Rails.application.message_verifier(:google_calendar_oauth)
         .generate({ account_id: account.id, user_id: admin.id, nonce: nonce,
                     authorization_generation: connection.authorization_generation }, expires_in: 10.minutes)
  end

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('GOOGLE_OAUTH_CLIENT_ID', nil).and_return('google-client')
    allow(GlobalConfigService).to receive(:load).with('GOOGLE_OAUTH_CLIENT_SECRET', nil).and_return('google-secret')
    stub_request(:post, 'https://oauth2.googleapis.com/token').to_return(
      status: 200,
      body: {
        access_token: 'access-secret', refresh_token: 'refresh-secret', expires_in: 3600,
        token_type: 'Bearer',
        scope: AiLeadEmployee::GoogleCalendarConnection::REQUIRED_SCOPES.join(' ')
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  it 'exchanges a single-use state and stores the granted Calendar scopes encrypted' do
    get '/google_calendar/callback', params: { state: state, code: 'authorization-code' }

    expect(response).to redirect_to(/booking-business-hours\?connected=true/)
    expect(connection.reload).to have_attributes(status: 'connected', access_token: 'access-secret',
                                                 refresh_token: 'refresh-secret', oauth_state_digest: nil)
    expect(connection.granted_scopes).to match_array(AiLeadEmployee::GoogleCalendarConnection::REQUIRED_SCOPES)
  end

  it 'fails closed when a signed state is replayed after its nonce was consumed' do
    connection.update!(oauth_state_digest: nil, oauth_state_expires_at: nil)
    get '/google_calendar/callback', params: { state: state, code: 'authorization-code' }

    expect(response).to redirect_to(/calendar_error=stale_authorization/)
    expect(connection.reload).to have_attributes(status: 'disconnected', last_error_code: nil)
    expect(a_request(:post, 'https://oauth2.googleapis.com/token')).not_to have_been_made
  end

  it 'does not let an old callback reconnect after an administrator disconnects during exchange' do
    stub_request(:post, 'https://oauth2.googleapis.com/token').to_return do
      connection.disconnect!
      {
        status: 200,
        body: { access_token: 'stale-secret', refresh_token: 'stale-refresh', expires_in: 3600,
                scope: AiLeadEmployee::GoogleCalendarConnection::REQUIRED_SCOPES.join(' ') }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end

    get '/google_calendar/callback', params: { state: state, code: 'authorization-code' }

    expect(response).to redirect_to(/calendar_error=stale_authorization/)
    expect(connection.reload).to have_attributes(status: 'disconnected', access_token: nil, refresh_token: nil)
  end

  it 'does not store a grant when administrator access is revoked during exchange' do
    stub_request(:post, 'https://oauth2.googleapis.com/token').to_return do
      AccountUser.find_by!(account: account, user: admin).update!(role: :agent)
      {
        status: 200,
        body: { access_token: 'revoked-secret', refresh_token: 'revoked-refresh', expires_in: 3600,
                scope: AiLeadEmployee::GoogleCalendarConnection::REQUIRED_SCOPES.join(' ') }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      }
    end

    get '/google_calendar/callback', params: { state: state, code: 'authorization-code' }

    expect(response).to redirect_to(/calendar_error=stale_authorization/)
    expect(connection.reload).to have_attributes(status: 'disconnected', access_token: nil, refresh_token: nil)
  end

  it 'records denied or incomplete consent as a permission error' do
    get '/google_calendar/callback', params: { state: state, error: 'access_denied' }

    expect(response).to redirect_to(/calendar_error=permission_denied/)
    expect(connection.reload).to have_attributes(status: 'permission_error', last_error_code: 'oauth_permission_denied')
  end

  it 'records a grant missing required scopes as a permission error' do
    stub_request(:post, 'https://oauth2.googleapis.com/token').to_return(
      status: 200,
      body: { access_token: 'partial-secret', expires_in: 3600, scope: 'openid email' }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    get '/google_calendar/callback', params: { state: state, code: 'authorization-code' }

    expect(response).to redirect_to(/calendar_error=permission_denied/)
    expect(connection.reload).to have_attributes(status: 'permission_error', last_error_code: 'oauth_permission_denied')
  end
end
