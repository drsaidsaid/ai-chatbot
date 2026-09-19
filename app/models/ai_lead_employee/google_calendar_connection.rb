# frozen_string_literal: true

class AiLeadEmployee::GoogleCalendarConnection < ApplicationRecord
  self.table_name = 'google_calendar_connections'

  REQUIRED_SCOPES = %w[
    https://www.googleapis.com/auth/calendar.events
    https://www.googleapis.com/auth/calendar.freebusy
  ].freeze

  belongs_to :account

  encrypts :access_token, :refresh_token if Chatwoot.encryption_configured?

  enum :status, { disconnected: 0, connected: 1, permission_error: 2, connection_error: 3 }

  validates :provider, inclusion: { in: %w[google_calendar] }
  validates :calendar_id, presence: true
  validate :credentials_require_configured_encryption

  def public_payload
    {
      provider: provider,
      status: status,
      connected: connected?,
      calendar_id: calendar_id,
      account_email: account_email,
      last_error_code: last_error_code,
      last_checked_at: last_checked_at&.iso8601,
      granted_scopes: granted_scopes
    }
  end

  def token_expired?
    token_expires_at.blank? || token_expires_at <= 5.minutes.from_now
  end

  def disconnect!
    with_lock do
      update!(status: :disconnected, access_token: nil, refresh_token: nil, token_expires_at: nil,
              account_email: nil, granted_scopes: [], last_error_code: nil, last_checked_at: Time.current,
              oauth_state_digest: nil, oauth_state_expires_at: nil,
              authorization_generation: authorization_generation + 1)
    end
  end

  private

  def credentials_require_configured_encryption
    return if access_token.blank? && refresh_token.blank?
    return if Chatwoot.encryption_configured?

    errors.add(:base, 'Calendar credentials cannot be stored until Active Record encryption is configured')
  end
end
