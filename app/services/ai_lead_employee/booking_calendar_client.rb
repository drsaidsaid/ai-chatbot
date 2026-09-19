# frozen_string_literal: true

class AiLeadEmployee::BookingCalendarClient
  FreeBusyResult = Data.define(:busy_slots, :state, :error_code)

  def initialize(account:, adapter: nil)
    @account = account
    @adapter = adapter || AiLeadEmployee::GoogleCalendarClient.new(account: account)
  end

  def free_busy(time_min:, time_max:, calendar_id:)
    adapter.free_busy(time_min: time_min, time_max: time_max, calendar_id: calendar_id)
  end

  def create_event!(booking:)
    adapter.create_event!(booking: booking)
  end

  def update_event!(booking:)
    adapter.update_event!(booking: booking)
  end

  def cancel_event!(booking:)
    adapter.cancel_event!(booking: booking)
  end

  def fetch_event!(calendar_id:, event_id:)
    adapter.fetch_event!(calendar_id: calendar_id, event_id: event_id)
  end

  private

  attr_reader :account, :adapter
end
