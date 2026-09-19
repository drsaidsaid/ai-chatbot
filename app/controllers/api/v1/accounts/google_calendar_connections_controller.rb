# frozen_string_literal: true

class Api::V1::Accounts::GoogleCalendarConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    record = current_account.google_calendar_connection ||
             current_account.build_google_calendar_connection(provider: 'google_calendar', calendar_id: 'primary')
    render json: record.public_payload
  end

  def create
    nonce = SecureRandom.urlsafe_base64(32)
    state = authorization_state(nonce)
    render json: { authorization_url: oauth_client.auth_code.authorize_url(
      redirect_uri: callback_url, scope: AiLeadEmployee::GoogleCalendarConnection::REQUIRED_SCOPES.join(' '),
      state: state, access_type: 'offline', prompt: 'consent', include_granted_scopes: true
    ) }
  end

  def destroy
    connection.disconnect!
    render json: connection.public_payload
  end

  private

  def authorization_state(nonce)
    generation = connection.with_lock do
      connection.update!(oauth_state_digest: Digest::SHA256.hexdigest(nonce), oauth_state_expires_at: 10.minutes.from_now,
                         authorization_generation: connection.authorization_generation + 1)
      connection.authorization_generation
    end
    verifier.generate(
      { account_id: current_account.id, user_id: current_user.id, nonce: nonce, authorization_generation: generation },
      expires_in: 10.minutes
    )
  end

  def connection
    @connection ||= current_account.google_calendar_connection ||
                    current_account.build_google_calendar_connection(provider: 'google_calendar', calendar_id: 'primary').tap(&:save!)
  end

  def verifier
    Rails.application.message_verifier(:google_calendar_oauth)
  end

  def oauth_client
    OAuth2::Client.new(GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_ID', nil),
                       GlobalConfigService.load('GOOGLE_OAUTH_CLIENT_SECRET', nil),
                       site: 'https://oauth2.googleapis.com', authorize_url: 'https://accounts.google.com/o/oauth2/v2/auth',
                       token_url: '/token')
  end

  def callback_url
    ENV.fetch('GOOGLE_CALENDAR_OAUTH_REDIRECT_URI') { "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/google_calendar/callback" }
  end
end
