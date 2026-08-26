# frozen_string_literal: true

class AiLeadEmployee::BookingConfiguration
  DEFAULTS = {
    'provider' => 'local_calendar',
    'calendar_id' => 'default',
    'connected' => false,
    'timezone' => 'UTC',
    'working_days' => [1, 2, 3, 4, 5],
    'allowed_hours' => { 'start' => '09:00', 'end' => '17:00' },
    'duration_minutes' => 30,
    'buffer_before_minutes' => 0,
    'buffer_after_minutes' => 0,
    'minimum_notice_minutes' => 120,
    'busy_slots' => []
  }.freeze

  def self.for(account)
    DEFAULTS.deep_merge(account.settings&.dig('ai_lead_employee', 'booking').to_h)
  end
end
