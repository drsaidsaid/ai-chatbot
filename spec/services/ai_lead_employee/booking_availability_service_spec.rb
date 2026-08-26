# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::BookingAvailabilityService do
  let(:account) do
    create(
      :account,
      settings: {
        'ai_lead_employee' => {
          'booking' => {
            'connected' => true,
            'calendar_id' => 'sales',
            'timezone' => 'Africa/Dar_es_Salaam',
            'working_days' => [1],
            'allowed_hours' => { 'start' => '09:00', 'end' => '11:00' },
            'duration_minutes' => 30,
            'buffer_before_minutes' => 15,
            'buffer_after_minutes' => 15,
            'minimum_notice_minutes' => 60,
            'busy_slots' => [
              { 'start' => '2026-08-31T06:30:00Z', 'end' => '2026-08-31T07:00:00Z' }
            ]
          }
        }
      }
    )
  end

  it 'offers only slots allowed by business hours, minimum notice, calendar busy time, and active bookings' do
    create(
      :booking,
      account: account,
      calendar_id: 'sales',
      starts_at: Time.zone.parse('2026-08-31T07:00:00Z'),
      ends_at: Time.zone.parse('2026-08-31T07:30:00Z')
    )

    travel_to Time.zone.parse('2026-08-31T05:00:00Z') do
      slots = described_class.new(account: account, from: Time.current, days: 1).perform.slots.map(&:iso8601)

      expect(slots).to eq(['2026-08-31T06:00:00Z'])
    end
  end

  it 'offers no slots until a calendar is connected' do
    account.update!(settings: account.settings.deep_merge('ai_lead_employee' => { 'booking' => { 'connected' => false } }))

    result = described_class.new(account: account, from: Time.zone.parse('2026-08-31T05:00:00Z'), days: 1).perform

    expect(result.slots).to be_empty
  end
end
