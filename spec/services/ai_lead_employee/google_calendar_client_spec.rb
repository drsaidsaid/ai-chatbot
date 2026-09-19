# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::GoogleCalendarClient do
  let(:account) { create(:account) }
  let!(:connection) do
    create(
      :google_calendar_connection,
      account: account,
      calendar_id: 'sales@example.test',
      access_token: nil,
      refresh_token: nil
    ).tap do |record|
      allow(record).to receive(:access_token).and_return('google-access-secret')
      allow(record).to receive(:token_expired?).and_return(false)
    end
  end
  let(:client) { described_class.new(account: account, connection: connection) }

  before do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
  end

  it 'returns a connected empty-calendar result separately from a provider failure' do
    stub_request(:post, 'https://www.googleapis.com/calendar/v3/freeBusy')
      .with(headers: { 'Authorization' => 'Bearer google-access-secret' })
      .to_return(status: 200, body: { calendars: { 'sales@example.test' => { busy: [] } } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    result = client.free_busy(
      time_min: Time.zone.parse('2026-09-21T06:00:00Z'),
      time_max: Time.zone.parse('2026-09-22T06:00:00Z'),
      calendar_id: 'sales@example.test'
    )

    expect(result).to have_attributes(state: 'connected', busy_slots: [], error_code: nil)
    expect(connection.reload).to have_attributes(status: 'connected', last_error_code: nil)
  end

  it 'records an insufficient permission response without presenting it as no availability' do
    stub_request(:post, 'https://www.googleapis.com/calendar/v3/freeBusy')
      .to_return(status: 403, body: { error: { errors: [{ reason: 'insufficientPermissions' }] } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    result = client.free_busy(
      time_min: Time.zone.parse('2026-09-21T06:00:00Z'),
      time_max: Time.zone.parse('2026-09-22T06:00:00Z'),
      calendar_id: 'sales@example.test'
    )

    expect(result).to have_attributes(state: 'permission_error', busy_slots: [], error_code: 'insufficient_permissions')
    expect(connection.reload).to have_attributes(status: 'permission_error', last_error_code: 'insufficient_permissions')
  end

  it 'does not turn a missing calendar response into apparent free time' do
    stub_request(:post, 'https://www.googleapis.com/calendar/v3/freeBusy')
      .to_return(status: 404, body: { error: { code: 404 } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    result = client.free_busy(
      time_min: Time.zone.parse('2026-09-21T06:00:00Z'),
      time_max: Time.zone.parse('2026-09-22T06:00:00Z'),
      calendar_id: 'sales@example.test'
    )

    expect(result).to have_attributes(state: 'permission_error', busy_slots: [], error_code: 'event_not_found')
    expect(connection.reload).to have_attributes(status: 'permission_error', last_error_code: 'event_not_found')
  end

  it 'uses a deterministic provider event id and includes only the explicitly supplied attendee email' do
    booking = create(:booking, account: account, attendee_email: 'lead@example.test', calendar_id: 'sales@example.test')
    request = stub_request(:post, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events})
              .to_return(status: 200, body: { id: 'provider-event-1', htmlLink: 'https://calendar.google.test/event/1' }.to_json,
                         headers: { 'Content-Type' => 'application/json' })

    result = client.create_event!(booking: booking)

    expect(result).to include('provider_event_id' => 'provider-event-1')
    expect(request.with do |provider_request|
      payload = JSON.parse(provider_request.body)
      payload.fetch('id') == described_class.event_id_for(booking) &&
        payload.fetch('attendees') == [{ 'email' => 'lead@example.test' }] &&
        payload.dig('conferenceData', 'createRequest', 'requestId') == described_class.event_id_for(booking)
    end).to have_been_requested
  end

  it 'reconciles a duplicate deterministic create by fetching the existing event' do
    booking = create(:booking, account: account, calendar_id: 'sales@example.test')
    event_id = described_class.event_id_for(booking)
    stub_request(:post, %r{/calendar/v3/calendars/.+/events})
      .to_return(status: 409, body: { error: { errors: [{ reason: 'duplicate' }] } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, %r{/calendar/v3/calendars/.+/events/#{event_id}})
      .to_return(status: 200, body: { id: event_id, status: 'confirmed' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    expect(client.create_event!(booking: booking)).to include('provider_event_id' => event_id,
                                                              'calendar_state' => 'confirmed')
  end

  it 'updates and cancels the same provider event, treating an already absent event as canceled' do
    booking = create(:booking, account: account, calendar_id: 'sales@example.test', provider_event_id: 'provider-event-1')
    patch_request = stub_request(:patch, %r{/calendar/v3/calendars/.+/events/provider-event-1})
                    .to_return(status: 200, body: { id: 'provider-event-1' }.to_json,
                               headers: { 'Content-Type' => 'application/json' })
    delete_request = stub_request(:delete, %r{/calendar/v3/calendars/.+/events/provider-event-1})
                     .to_return(status: 404, body: { error: { code: 404 } }.to_json,
                                headers: { 'Content-Type' => 'application/json' })

    expect(client.update_event!(booking: booking)).to include('provider_event_id' => 'provider-event-1')
    expect(client.cancel_event!(booking: booking)).to include('calendar_state' => 'canceled')
    expect(patch_request).to have_been_requested.once
    expect(delete_request).to have_been_requested.once
  end

  it 'classifies both missing and gone event fetches as event_not_found' do
    [404, 410].each do |status|
      stub_request(:get, %r{/calendar/v3/calendars/.+/events/provider-event-#{status}})
        .to_return(status: status, body: { error: { code: status } }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect do
        client.fetch_event!(calendar_id: 'sales@example.test', event_id: "provider-event-#{status}")
      end.to raise_error(described_class::ProviderFailure) { |error| expect(error.error_code).to eq('event_not_found') }
    end
  end

  it 'does not let an in-flight request reconnect a generation that was disconnected' do
    response = instance_double(Faraday::Response, success?: true,
                                                  body: { calendars: { 'sales@example.test' => { busy: [] } } }.to_json)
    request = Struct.new(:headers, :params, :body).new({}, {})
    http = instance_double(Faraday::Connection)
    allow(http).to receive(:post) do |_url, &block|
      block.call(request)
      connection.disconnect!
      response
    end
    stale_client = described_class.new(account: account, connection: connection, http: http)

    stale_client.free_busy(time_min: Time.current, time_max: 1.day.from_now, calendar_id: 'sales@example.test')

    expect(connection.reload).to have_attributes(status: 'disconnected', last_error_code: nil)
  end

  it 'discards refreshed credentials when authorization changes during token refresh' do
    allow(connection).to receive(:access_token).and_call_original
    allow(connection).to receive(:refresh_token).and_call_original
    connection.update!(access_token: 'old-token', refresh_token: 'refresh-secret')
    allow(connection).to receive(:token_expired?).and_return(true)
    refreshed = instance_double(OAuth2::AccessToken, token: 'new-token', refresh_token: 'new-refresh', expires_at: 1.hour.from_now.to_i)
    access_token = instance_double(OAuth2::AccessToken)
    allow(access_token).to receive(:refresh!) do
      connection.disconnect!
      refreshed
    end
    allow(OAuth2::AccessToken).to receive(:new).and_return(access_token)

    expect do
      client.free_busy(time_min: Time.current, time_max: 1.day.from_now, calendar_id: 'sales@example.test')
    end.to change { connection.reload.authorization_generation }.by(1)
    expect(connection.reload).to have_attributes(status: 'disconnected', access_token: nil, refresh_token: nil)
  end
end
