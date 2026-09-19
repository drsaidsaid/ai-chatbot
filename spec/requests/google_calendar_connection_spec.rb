# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Google Calendar connection', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('GOOGLE_OAUTH_CLIENT_ID', nil).and_return('google-client')
    allow(GlobalConfigService).to receive(:load).with('GOOGLE_OAUTH_CLIENT_SECRET', nil).and_return('google-secret')
  end

  it 'issues a short-lived, account-and-user-bound authorization state for an admin' do
    post "/api/v1/accounts/#{account.id}/google_calendar_connection", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    uri = URI.parse(response.parsed_body.fetch('authorization_url'))
    query = Rack::Utils.parse_query(uri.query)
    state = Rails.application.message_verifier(:google_calendar_oauth).verify(query.fetch('state'))
    connection = account.reload.google_calendar_connection
    expect(state).to include(account_id: account.id, user_id: admin.id,
                             authorization_generation: connection.authorization_generation)
    expect(query.fetch('scope')).to include('calendar.events', 'calendar.freebusy')
    expect(connection).to have_attributes(status: 'disconnected', oauth_state_digest: be_present,
                                          oauth_state_expires_at: be_present)
  end

  it 'does not allow an operator to initiate or disconnect account calendar access' do
    post "/api/v1/accounts/#{account.id}/google_calendar_connection", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)

    delete "/api/v1/accounts/#{account.id}/google_calendar_connection", headers: agent.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'disconnects without returning stored credentials' do
    connection = create(:google_calendar_connection, account: account, status: :connected,
                                                     access_token: nil, refresh_token: nil)
    delete "/api/v1/accounts/#{account.id}/google_calendar_connection", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('connected' => false, 'status' => 'disconnected')
    expect(response.body).not_to include('access_token', 'refresh_token')
    expect(connection.reload).to be_disconnected
    expect(connection.authorization_generation).to eq(1)
  end
end
