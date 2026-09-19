# frozen_string_literal: true

class AiLeadEmployee::BookingAvailabilityService
  Result = Data.define(:slots, :provider_state, :error_code)

  def initialize(account:, from: Time.current, days: 7, calendar_client: nil, exclude_booking: nil)
    @account = account.reload
    @from = from
    @days = days.to_i.clamp(1, 31)
    @configuration = AiLeadEmployee::BookingConfiguration.for(@account)
    @authority_digest = AiLeadEmployee::BookingConfiguration.authority_digest(@account, configuration: @configuration)
    @calendar_client_injected = calendar_client.present?
    @calendar_client = calendar_client || AiLeadEmployee::BookingCalendarClient.new(account: @account)
    @exclude_booking = exclude_booking
  end

  attr_reader :authority_digest

  def perform
    return result([], 'disconnected', 'calendar_not_connected') unless configuration['calendar_access_configured'] || calendar_client_injected?

    provider = calendar_client.free_busy(time_min: provider_window.first, time_max: provider_window.last, calendar_id: calendar_id)
    return result([], provider.state, provider.error_code) unless provider.state == 'connected'

    @busy_slots = provider.busy_slots
    result(candidate_slots.select { |slot| available_slot?(slot) }, 'connected', nil)
  end

  private

  attr_reader :account, :from, :days, :configuration, :calendar_client

  def result(slots, provider_state, error_code)
    Result.new(slots: slots, provider_state: provider_state, error_code: error_code)
  end

  def calendar_client_injected?
    @calendar_client_injected
  end

  def provider_window
    first_date = from.in_time_zone(timezone).to_date
    @provider_window ||= [
      local_time(first_date, '00:00').utc - buffer_before,
      local_time(first_date + days.days, '00:00').utc + buffer_after
    ]
  end

  def candidate_slots
    (0...days).flat_map do |offset|
      local_day = from.in_time_zone(timezone).to_date + offset.days
      next [] unless working_day?(local_day) && available_date?(local_day)

      slots_for_day(local_day)
    end
  end

  def slots_for_day(local_day)
    cursor = local_time(local_day, allowed_hours.fetch('start'))
    finish = local_time(local_day, allowed_hours.fetch('end'))
    slots = []

    while cursor + duration <= finish
      slots << cursor.utc if cursor.utc >= minimum_start_time
      cursor += duration
    end

    slots
  end

  def available_slot?(starts_at)
    ends_at = starts_at + duration
    !busy_slot?(starts_at, ends_at) && !booked_slot?(starts_at, ends_at)
  end

  def busy_slot?(starts_at, ends_at)
    busy_slots.any? do |slot|
      overlaps?(starts_at - buffer_before, ends_at + buffer_after,
                Time.zone.parse(slot.fetch('start')), Time.zone.parse(slot.fetch('end')))
    end
  end

  def booked_slot?(starts_at, ends_at)
    scope = Booking.active.where(account: account, calendar_id: calendar_id)
    scope = scope.where.not(id: @exclude_booking.id) if @exclude_booking
    scope.exists?(['starts_at < ? AND ends_at > ?', ends_at + buffer_after, starts_at - buffer_before])
  end

  def overlaps?(starts_at, ends_at, busy_starts_at, busy_ends_at)
    starts_at < busy_ends_at && ends_at > busy_starts_at
  end

  def working_day?(local_day)
    working_days.include?(local_day.wday)
  end

  def available_date?(local_day)
    exception = exceptions.find { |item| item['date'] == local_day.iso8601 }
    !exception || exception['unavailable'] != true
  end

  def local_time(local_day, value)
    hour, minute = value.split(':').map(&:to_i)
    timezone.local(local_day.year, local_day.month, local_day.day, hour, minute)
  end

  def allowed_hours
    configuration.fetch('allowed_hours')
  end

  def busy_slots
    Array(@busy_slots)
  end

  def exceptions
    Array(configuration['exceptions'])
  end

  def working_days
    Array(configuration['working_days']).map(&:to_i)
  end

  def calendar_id
    configuration.fetch('calendar_id')
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[configuration.fetch('timezone')] || ActiveSupport::TimeZone['UTC']
  end

  def duration
    configuration.fetch('duration_minutes').to_i.minutes
  end

  def buffer_before
    configuration.fetch('buffer_before_minutes').to_i.minutes
  end

  def buffer_after
    configuration.fetch('buffer_after_minutes').to_i.minutes
  end

  def minimum_start_time
    Time.current + configuration.fetch('minimum_notice_minutes').to_i.minutes
  end
end
