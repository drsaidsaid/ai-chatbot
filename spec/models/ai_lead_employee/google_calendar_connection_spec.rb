# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::GoogleCalendarConnection do
  it 'requires encrypted storage before accepting OAuth credentials' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(false)

    connection = build(:google_calendar_connection, access_token: 'google-access-secret', refresh_token: 'google-refresh-secret')

    expect(connection).not_to be_valid
    expect(connection.errors[:base]).to include('Calendar credentials cannot be stored until Active Record encryption is configured')
  end

  it 'exposes connection health without returning OAuth credentials' do
    connection = build(
      :google_calendar_connection,
      calendar_id: 'sales@example.test',
      account_email: 'owner@example.test',
      granted_scopes: ['https://www.googleapis.com/auth/calendar'],
      last_checked_at: Time.zone.parse('2026-09-19T08:00:00Z')
    )

    payload = connection.public_payload

    expect(payload).to include(
      provider: 'google_calendar',
      status: 'connected',
      calendar_id: 'sales@example.test',
      account_email: 'owner@example.test'
    )
    expect(payload.to_json).not_to include('google-access-secret', 'google-refresh-secret')
  end
end
