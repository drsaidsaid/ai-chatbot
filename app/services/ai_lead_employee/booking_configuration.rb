# frozen_string_literal: true

class AiLeadEmployee::BookingConfiguration
  DEFAULTS = {
    'provider' => 'google_calendar',
    'calendar_id' => 'primary',
    'timezone' => 'UTC',
    'working_days' => [1, 2, 3, 4, 5],
    'allowed_hours' => { 'start' => '09:00', 'end' => '17:00' },
    'duration_minutes' => 30,
    'buffer_before_minutes' => 0,
    'buffer_after_minutes' => 0,
    'minimum_notice_minutes' => 120,
    'exceptions' => []
  }.freeze

  def self.for(account)
    connection = account.google_calendar_connection
    saved = account.settings&.dig('ai_lead_employee', 'booking').to_h.slice(*DEFAULTS.keys)
    DEFAULTS.deep_merge(saved).merge(
      'connected' => connection&.connected? || false,
      'calendar_access_configured' => connection&.status.in?(%w[connected connection_error]) || false
    )
  end

  def self.authority_digest(account, configuration: nil)
    connection = account.google_calendar_connection
    stable_configuration = (configuration || self.for(account)).slice(*DEFAULTS.keys)
    payload = {
      'configuration' => stable_configuration,
      'connection' => connection && {
        'id' => connection.id,
        'calendar_id' => connection.calendar_id,
        'authorization_generation' => connection.authorization_generation
      }
    }
    Digest::SHA256.hexdigest(JSON.generate(payload))
  end
end
