# frozen_string_literal: true

class AiLeadEmployee::GoogleCalendarClient # rubocop:disable Metrics/ClassLength
  API_ROOT = 'https://www.googleapis.com/calendar/v3'
  TOKEN_SITE = 'https://oauth2.googleapis.com'

  class ProviderFailure < StandardError
    attr_reader :error_code, :state

    def initialize(error_code:, state:, message: nil)
      @error_code = error_code
      @state = state
      super(message || error_code.humanize)
    end

    def uncertain?
      state == 'connection_error'
    end
  end

  def self.event_id_for(booking)
    "ailead#{Digest::SHA256.hexdigest("booking:#{booking.account_id}:#{booking.id}")[0, 32]}"
  end

  def initialize(account:, connection: nil, http: nil)
    @account = account
    @connection = connection || account.google_calendar_connection
    @authorization_generation = @connection&.authorization_generation
    @http = http || Faraday.new
  end

  def free_busy(time_min:, time_max:, calendar_id:) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return free_busy_result([], 'disconnected', 'calendar_not_connected') unless connection&.status.in?(%w[connected connection_error])

    response = request(:post, '/freeBusy', body: {
                         timeMin: time_min.iso8601, timeMax: time_max.iso8601, timeZone: 'UTC', items: [{ id: calendar_id }]
                       })
    payload = response_payload(response)
    calendar = payload.fetch('calendars', {}).fetch(calendar_id, {})
    if calendar['errors'].present?
      failure = failure_from_reasons(calendar['errors'].pluck('reason'))
      record_failure!(failure)
      return free_busy_result([], failure.state, failure.error_code)
    end

    record_connected!
    free_busy_result(Array(calendar['busy']), 'connected', nil)
  rescue ProviderFailure => e
    record_failure!(e)
    free_busy_result([], e.state, e.error_code)
  rescue Faraday::Error, Timeout::Error => e
    failure = ProviderFailure.new(error_code: 'provider_unreachable', state: 'connection_error', message: e.message)
    record_failure!(failure)
    free_busy_result([], failure.state, failure.error_code)
  end

  def create_event!(booking:)
    event_id = self.class.event_id_for(booking)
    response = request(
      :post,
      "/calendars/#{escape(booking.calendar_id)}/events",
      query: { conferenceDataVersion: 1, sendUpdates: send_updates(booking) },
      body: event_payload(booking, include_conference: true).merge(id: event_id)
    )
    record_connected!
    provider_payload(response_payload(response), booking)
  rescue ProviderFailure => e
    return provider_payload(fetch_event!(calendar_id: booking.calendar_id, event_id: event_id), booking) if e.error_code == 'duplicate_event'

    record_failure!(e)
    raise
  end

  def update_event!(booking:)
    response = request(
      :patch,
      "/calendars/#{escape(booking.calendar_id)}/events/#{escape(booking.provider_event_id)}",
      query: { sendUpdates: send_updates(booking) },
      body: event_payload(booking)
    )
    record_connected!
    provider_payload(response_payload(response), booking)
  rescue ProviderFailure => e
    record_failure!(e)
    raise
  end

  def cancel_event!(booking:)
    request(
      :delete,
      "/calendars/#{escape(booking.calendar_id)}/events/#{escape(booking.provider_event_id)}",
      query: { sendUpdates: send_updates(booking) }
    )
    record_connected!
    { 'provider_event_id' => booking.provider_event_id, 'calendar_state' => 'canceled' }
  rescue ProviderFailure => e
    return { 'provider_event_id' => booking.provider_event_id, 'calendar_state' => 'canceled' } if e.error_code == 'event_not_found'

    record_failure!(e)
    raise
  end

  def fetch_event!(calendar_id:, event_id:)
    payload = response_payload(request(:get, "/calendars/#{escape(calendar_id)}/events/#{escape(event_id)}"))
    record_connected!
    payload
  end

  private

  attr_reader :account, :connection, :http, :authorization_generation

  def request(method, path, query: {}, body: nil)
    response = http.public_send(method, "#{API_ROOT}#{path}") do |request|
      request.headers['Authorization'] = "Bearer #{access_token}"
      request.headers['Content-Type'] = 'application/json'
      request.params.update(query)
      request.body = body.to_json if body
    end
    return response if response.success?

    raise response_failure(response)
  rescue Faraday::Error, Timeout::Error => e
    raise ProviderFailure.new(error_code: 'provider_unreachable', state: 'connection_error', message: e.message)
  end

  def access_token
    refresh_access_token! if connection.token_expired?
    connection.access_token
  end

  def refresh_access_token! # rubocop:disable Metrics/AbcSize
    raise ProviderFailure.new(error_code: 'refresh_token_missing', state: 'permission_error') if connection.refresh_token.blank?

    token = OAuth2::AccessToken.new(oauth_client, connection.access_token, refresh_token: connection.refresh_token).refresh!
    connection.with_lock do
      connection.reload
      raise ProviderFailure.new(error_code: 'authorization_changed', state: 'permission_error') unless current_generation?

      connection.update!(
        access_token: token.token,
        refresh_token: token.refresh_token.presence || connection.refresh_token,
        token_expires_at: token.expires_at && Time.zone.at(token.expires_at),
        status: :connected,
        last_error_code: nil,
        last_checked_at: Time.current
      )
    end
  rescue OAuth2::Error => e
    raise ProviderFailure.new(error_code: 'token_refresh_failed', state: 'permission_error', message: e.message)
  end

  def oauth_client
    OAuth2::Client.new(
      GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
      GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil),
      site: TOKEN_SITE,
      token_url: '/token'
    )
  end

  def response_failure(response) # rubocop:disable Metrics/CyclomaticComplexity
    payload = response_payload(response)
    reason = Array(payload.dig('error', 'errors')).first&.fetch('reason', nil)
    return ProviderFailure.new(error_code: 'duplicate_event', state: 'connected') if response.status == 409 && reason == 'duplicate'
    return ProviderFailure.new(error_code: 'event_not_found', state: 'permission_error') if response.status.in?([404, 410])
    return ProviderFailure.new(error_code: 'insufficient_permissions', state: 'permission_error') if response.status.in?([401, 403])

    ProviderFailure.new(
      error_code: response.status >= 500 ? 'provider_unreachable' : 'provider_rejected',
      state: response.status >= 500 ? 'connection_error' : 'permission_error'
    )
  end

  def failure_from_reasons(reasons)
    permission = reasons.any? { |reason| reason.in?(%w[forbidden insufficientPermissions notFound]) }
    ProviderFailure.new(
      error_code: permission ? 'insufficient_permissions' : 'provider_unreachable',
      state: permission ? 'permission_error' : 'connection_error'
    )
  end

  def response_payload(response)
    return {} if response.body.blank?

    response.body.is_a?(String) ? JSON.parse(response.body) : response.body
  rescue JSON::ParserError
    {}
  end

  def event_payload(booking, include_conference: false)
    payload = {
      summary: booking.offer&.name.presence || 'Lead call',
      description: "AI Lead Employee booking ##{booking.id}",
      start: { dateTime: booking.starts_at.iso8601, timeZone: booking.timezone },
      end: { dateTime: booking.ends_at.iso8601, timeZone: booking.timezone },
      attendees: booking.attendee_email.present? ? [{ email: booking.attendee_email }] : [],
      extendedProperties: { private: { aiLeadBookingId: booking.id.to_s, accountId: booking.account_id.to_s } }
    }
    if include_conference
      payload[:conferenceData] = {
        createRequest: {
          requestId: self.class.event_id_for(booking),
          conferenceSolutionKey: { type: 'hangoutsMeet' }
        }
      }
    end
    payload
  end

  def provider_payload(payload, booking)
    {
      'provider_event_id' => payload.fetch('id'),
      'provider' => 'google_calendar',
      'calendar_id' => booking.calendar_id,
      'starts_at' => booking.starts_at.iso8601,
      'ends_at' => booking.ends_at.iso8601,
      'invitee_email' => booking.attendee_email,
      'meeting_link' => payload['hangoutLink'],
      'html_link' => payload['htmlLink'],
      'etag' => payload['etag'],
      'calendar_state' => 'confirmed'
    }.compact
  end

  def send_updates(booking)
    booking.attendee_email.present? ? 'all' : 'none'
  end

  def record_connected!
    updated = update_connection_if_current(status: :connected, last_error_code: nil, last_checked_at: Time.current)
    return if updated == 1

    raise ProviderFailure.new(error_code: 'authorization_changed', state: 'permission_error')
  end

  def record_failure!(failure)
    update_connection_if_current(status: failure.state, last_error_code: failure.error_code, last_checked_at: Time.current)
  end

  def update_connection_if_current(attributes)
    return unless connection

    updated = connection.class.where(id: connection.id, authorization_generation: authorization_generation).update_all(attributes) # rubocop:disable Rails/SkipsModelValidations
    connection.reload
    updated
  end

  def current_generation?
    connection.authorization_generation == authorization_generation
  end

  def free_busy_result(busy_slots, state, error_code)
    AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(
      busy_slots: busy_slots,
      state: state,
      error_code: error_code
    )
  end

  def escape(value)
    ERB::Util.url_encode(value.to_s)
  end
end
