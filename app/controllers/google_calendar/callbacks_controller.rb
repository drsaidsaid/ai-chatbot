# frozen_string_literal: true

class GoogleCalendar::CallbacksController < ApplicationController
  class PermissionDenied < StandardError; end
  class StaleAuthorization < StandardError; end
  class AuthorizationRevoked < StandardError; end

  def show # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    payload = verifier.verify(params.require(:state))
    account = Account.find(payload.fetch(:account_id))
    user = User.find(payload.fetch(:user_id))
    membership = AccountUser.find_by!(account: account, user: user)
    raise Pundit::NotAuthorizedError unless membership.administrator?

    connection = account.google_calendar_connection || raise(ActiveRecord::RecordNotFound)
    generation = payload.fetch(:authorization_generation)
    connection.with_lock do
      raise StaleAuthorization unless connection.authorization_generation == generation

      verify_nonce!(connection, payload.fetch(:nonce))
      connection.update!(oauth_state_digest: nil, oauth_state_expires_at: nil)
    end
    raise PermissionDenied, params[:error] if params[:error].present?

    token = oauth_client.auth_code.get_token(params.require(:code), redirect_uri: callback_url)
    scopes = token.params.fetch('scope', '').to_s.split
    missing = AiLeadEmployee::GoogleCalendarConnection::REQUIRED_SCOPES - scopes
    raise PermissionDenied, "Missing required Calendar scopes: #{missing.join(', ')}" if missing.any?

    persist_grant!(account, user, connection, generation, token, scopes)
    redirect_to settings_url(account, connected: true), allow_other_host: true
  rescue PermissionDenied
    record_callback_failure(connection, generation, 'permission_error', 'oauth_permission_denied')
    redirect_to settings_url(account, calendar_error: 'permission_denied'), allow_other_host: true
  rescue StaleAuthorization, AuthorizationRevoked, ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to settings_url(account, calendar_error: 'stale_authorization'), allow_other_host: true
  rescue StandardError => e
    Rails.logger.warn("Google Calendar OAuth callback failed: #{e.class}")
    record_callback_failure(connection, generation, 'connection_error', 'oauth_connection_failed')
    redirect_to settings_url(account, calendar_error: 'connection_failed'), allow_other_host: true
  end

  private

  def verify_nonce!(connection, nonce)
    expected = Digest::SHA256.hexdigest(nonce)
    valid = connection.oauth_state_expires_at&.future? &&
            ActiveSupport::SecurityUtils.secure_compare(connection.oauth_state_digest.to_s, expected)
    raise ActiveSupport::MessageVerifier::InvalidSignature unless valid
  end

  def record_callback_failure(connection, generation, status, code)
    return unless connection && generation

    connection.with_lock do
      return unless connection.authorization_generation == generation

      connection.update!(status: status, last_error_code: code, last_checked_at: Time.current)
    end
  end

  def persist_grant!(account, user, connection, generation, token, scopes) # rubocop:disable Metrics/ParameterLists
    AccountUser.transaction do
      membership = AccountUser.lock.find_by(account: account, user: user)
      raise AuthorizationRevoked unless membership&.administrator?

      connection.lock!
      raise StaleAuthorization unless connection.authorization_generation == generation

      connection.update!(status: :connected, access_token: token.token,
                         refresh_token: token.refresh_token.presence || connection.refresh_token,
                         token_expires_at: token.expires_at && Time.zone.at(token.expires_at), granted_scopes: scopes,
                         last_error_code: nil, last_checked_at: Time.current)
    end
  end

  def verifier
    Rails.application.message_verifier(:google_calendar_oauth)
  end

  def oauth_client
    OAuth2::Client.new(GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
                       GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil),
                       site: 'https://oauth2.googleapis.com', token_url: '/token')
  end

  def callback_url
    ENV.fetch('GOOGLE_CALENDAR_OAUTH_REDIRECT_URI') { "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/google_calendar/callback" }
  end

  def settings_url(target_account, query)
    base = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    "#{base}/app/accounts/#{target_account&.id}/settings/ai-lead-employee/booking-business-hours?#{query.to_query}"
  end
end
