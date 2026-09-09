# frozen_string_literal: true

class AiLeadEmployee::BookingCalendarClient
  def initialize(account:)
    @account = account
  end

  def create_event!(booking:)
    {
      'provider_event_id' => "booking-#{booking.id}",
      'provider' => booking.provider,
      'calendar_id' => booking.calendar_id,
      'starts_at' => booking.starts_at.iso8601,
      'ends_at' => booking.ends_at.iso8601,
      'invitee_email' => booking.contact.email.presence
    }
  end

  private

  attr_reader :account
end
