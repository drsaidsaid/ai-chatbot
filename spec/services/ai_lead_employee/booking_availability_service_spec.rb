# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::BookingAvailabilityService do
  let(:calendar_client) do
    instance_double(
      AiLeadEmployee::BookingCalendarClient,
      free_busy: AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(
        busy_slots: [
          { 'start' => '2026-08-31T07:30:00Z', 'end' => '2026-08-31T08:00:00Z' }
        ],
        state: 'connected',
        error_code: nil
      )
    )
  end

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
            'exceptions' => [{ 'date' => '2026-09-01', 'unavailable' => true }]
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
      result = described_class.new(account: account, from: Time.current, days: 1, calendar_client: calendar_client).perform

      expect(result.slots.map(&:iso8601)).to eq(['2026-08-31T06:00:00Z'])
      expect(result).to have_attributes(provider_state: 'connected', error_code: nil)
    end
  end

  it 'distinguishes a provider permission failure from a connected calendar with no free slots' do
    permission_client = instance_double(
      AiLeadEmployee::BookingCalendarClient,
      free_busy: AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(
        busy_slots: [], state: 'permission_error', error_code: 'insufficient_scope'
      )
    )

    result = described_class.new(
      account: account,
      from: Time.zone.parse('2026-08-31T05:00:00Z'),
      days: 1,
      calendar_client: permission_client
    ).perform

    expect(result.slots).to be_empty
    expect(result).to have_attributes(provider_state: 'permission_error', error_code: 'insufficient_scope')
  end

  it 'applies saved date exceptions after the provider reports free time' do
    result = described_class.new(
      account: account,
      from: Time.zone.parse('2026-09-01T05:00:00Z'),
      days: 1,
      calendar_client: calendar_client
    ).perform

    expect(result.slots).to be_empty
    expect(result.provider_state).to eq('connected')
  end

  it 'applies asymmetric before and after buffers to the matching candidate edges' do
    account.update!(settings: account.settings.deep_merge(
      'ai_lead_employee' => { 'booking' => {
        'buffer_before_minutes' => 5,
        'buffer_after_minutes' => 20
      } }
    ))
    create(:booking, account: account, calendar_id: 'sales',
                     starts_at: Time.zone.parse('2026-08-31T06:45:00Z'),
                     ends_at: Time.zone.parse('2026-08-31T07:15:00Z'))
    free_calendar = instance_double(
      AiLeadEmployee::BookingCalendarClient,
      free_busy: AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(
        busy_slots: [], state: 'connected', error_code: nil
      )
    )

    result = travel_to Time.zone.parse('2026-08-31T05:00:00Z') do
      described_class.new(account: account, from: Time.current, days: 1, calendar_client: free_calendar).perform
    end

    expect(result.slots.map(&:iso8601)).not_to include('2026-08-31T06:00:00Z')
    expect(result.slots.map(&:iso8601)).to include('2026-08-31T07:30:00Z')
  end
end
