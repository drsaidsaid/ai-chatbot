# frozen_string_literal: true

class AiLeadEmployee::BookingAvailabilityService
  Result = Struct.new(:slots, keyword_init: true)

  def initialize(account:, from: Time.current, days: 7)
    @account = account
    @from = from
    @days = days.to_i
    @configuration = AiLeadEmployee::BookingConfiguration.for(account)
  end

  def perform
    return Result.new(slots: []) unless configuration['connected']

    Result.new(slots: candidate_slots.select { |slot| available_slot?(slot) })
  end

  private

  attr_reader :account, :from, :days, :configuration

  def candidate_slots
    (0...days).flat_map do |offset|
      local_day = from.in_time_zone(timezone).to_date + offset.days
      next [] unless working_day?(local_day)

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
    busy_slots.any? { |slot| overlaps?(starts_at, ends_at, Time.zone.parse(slot.fetch('start')), Time.zone.parse(slot.fetch('end'))) }
  end

  def booked_slot?(starts_at, ends_at)
    Booking.active
           .where(account: account, calendar_id: calendar_id)
           .exists?(['starts_at < ? AND ends_at > ?', ends_at + buffer_before, starts_at - buffer_after])
  end

  def overlaps?(starts_at, ends_at, busy_starts_at, busy_ends_at)
    starts_at < busy_ends_at && ends_at > busy_starts_at
  end

  def working_day?(local_day)
    working_days.include?(local_day.wday)
  end

  def local_time(local_day, value)
    hour, minute = value.split(':').map(&:to_i)
    timezone.local(local_day.year, local_day.month, local_day.day, hour, minute)
  end

  def allowed_hours
    configuration.fetch('allowed_hours')
  end

  def busy_slots
    Array(configuration['busy_slots'])
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
    from + configuration.fetch('minimum_notice_minutes').to_i.minutes
  end
end
