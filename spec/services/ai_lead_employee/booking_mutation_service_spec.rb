# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

# Stateful provider fakes make operation ordering and retry outcomes directly observable.
# rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/InstanceVariable, RSpec/LeakyConstantDeclaration
# rubocop:disable Style/MultilineBlockChain

RSpec.describe AiLeadEmployee::BookingMutationService do
  class MutationCalendarFake
    attr_reader :updates, :cancellations, :fetches, :free_busy_open_transactions

    def initialize(results: [], on_update: nil, on_free_busy: nil, on_fetch: nil, fetch_result: nil)
      @results = results
      @on_update = on_update
      @on_free_busy = on_free_busy
      @on_fetch = on_fetch
      @fetch_result = fetch_result
      @updates = []
      @cancellations = []
      @fetches = []
      @free_busy_open_transactions = []
    end

    def free_busy(**)
      free_busy_open_transactions << ActiveRecord::Base.connection.open_transactions
      @on_free_busy&.call
      AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(busy_slots: [], state: 'connected', error_code: nil)
    end

    def update_event!(booking:)
      updates << booking
      @on_update&.call(booking)
      result('confirmed', booking)
    end

    def cancel_event!(booking:)
      cancellations << booking
      result('canceled', booking)
    end

    def fetch_event!(calendar_id:, event_id:)
      fetches << { calendar_id: calendar_id, event_id: event_id }
      @on_fetch&.call
      raise @fetch_result if @fetch_result.is_a?(Exception)
      return @fetch_result if @fetch_result

      target = updates.last
      {
        'id' => event_id,
        'status' => 'confirmed',
        'start' => { 'dateTime' => target.starts_at.iso8601 },
        'end' => { 'dateTime' => target.ends_at.iso8601 }
      }
    end

    private

    def result(state, booking)
      value = @results.shift
      raise value if value.is_a?(Exception)

      value || { 'provider_event_id' => booking.provider_event_id, 'calendar_state' => state }
    end
  end

  let(:account) do
    create(:account, settings: { 'ai_lead_employee' => { 'booking' => {
             'timezone' => 'UTC', 'working_days' => [1, 2, 3, 4, 5],
             'allowed_hours' => { 'start' => '09:00', 'end' => '17:00' },
             'duration_minutes' => 30, 'minimum_notice_minutes' => 60
           } } })
  end
  let!(:connection) do
    create(:google_calendar_connection, account: account, status: :connected, access_token: nil, refresh_token: nil)
  end
  let(:user) { create(:user, account: account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, assignee: user, control_state: :human_active) }
  let(:qualification) { create(:lead_qualification, account: account, contact: conversation.contact, follow_up_state: :call_booked) }
  let(:booking) do
    create(:booking, account: account, conversation: conversation, contact: conversation.contact,
                     lead_qualification: qualification, assignee: user, calendar_id: 'primary',
                     provider_event_id: 'google-event-1', provider_state: 'confirmed',
                     starts_at: Time.zone.parse('2026-09-21 09:00'), ends_at: Time.zone.parse('2026-09-21 09:30'))
  end
  let(:calendar) { MutationCalendarFake.new }

  before { allow(Chatwoot).to receive(:encryption_configured?).and_return(true) }

  def mutate(action, key:, attributes: {}, client: calendar)
    described_class.new(account: account, user: user, booking: booking, action: action, attributes: attributes,
                        idempotency_key: key, calendar_client: client).perform
  end

  it 'rechecks availability, updates Google first, then persists one reschedule and canonical notice' do
    travel_to Time.zone.parse('2026-09-19 06:00') do
      test_transaction_depth = ActiveRecord::Base.connection.open_transactions
      result = mutate('reschedule', key: 'move-once', attributes: { starts_at: '2026-09-21T10:00:00Z' })
      duplicate = mutate('reschedule', key: 'move-once', attributes: { starts_at: '2026-09-21T10:00:00Z' })

      expect(result).to have_attributes(starts_at: Time.zone.parse('2026-09-21 10:00'), provider_state: 'confirmed')
      expect(duplicate.id).to eq(result.id)
      expect(calendar.updates.size).to eq(1)
      expect(calendar.free_busy_open_transactions).to eq([test_transaction_depth])
      expect(conversation.messages.outgoing.count).to eq(1)
      expect(result.calendar_event_payload.dig('mutations', 'move-once', 'state')).to eq('confirmed')
    end
  end

  it 'cancels Google before changing the local record and emits one notice' do
    result = mutate('cancel', key: 'cancel-once', attributes: { reason: 'Lead asked' })

    expect(result).to have_attributes(status: 'canceled', provider_state: 'canceled')
    expect(calendar.cancellations.size).to eq(1)
    expect(qualification.reload).to be_human_review
    expect(conversation.messages.outgoing.count).to eq(1)
  end

  it 'records a timeout as unknown without changing the agreed time or emitting a notice, then retries safely' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(error_code: 'provider_timeout', state: 'connection_error')
    client = MutationCalendarFake.new(results: [failure, nil])

    travel_to Time.zone.parse('2026-09-19 06:00') do
      expect do
        mutate('reschedule', key: 'move-unknown', attributes: { starts_at: '2026-09-21T10:00:00Z' }, client: client)
      end.to raise_error(described_class::ProviderUnknown)

      expect(booking.reload).to have_attributes(starts_at: Time.zone.parse('2026-09-21 09:00'), provider_state: 'unknown')
      expect(conversation.messages.outgoing.count).to eq(0)
      connection.update!(status: :connection_error, last_error_code: 'provider_timeout')

      result = AiLeadEmployee::BookingReconciliationService.new(
        account: account, user: user, booking: booking, calendar_client: client
      ).perform
      expect(result).to have_attributes(starts_at: Time.zone.parse('2026-09-21 10:00'), provider_state: 'confirmed')
      expect(client.updates.size).to eq(1)
      expect(client.fetches).to contain_exactly({ calendar_id: 'primary', event_id: 'google-event-1' })
      expect(conversation.messages.outgoing.count).to eq(1)
    end
  end

  it 'does not let a slower reconciliation timeout downgrade the same operation after another reconciler confirms it' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    target = Time.zone.parse('2026-09-21 10:00')
    initial = MutationCalendarFake.new(results: [failure])
    expect do
      mutate('reschedule', key: 'two-reconcilers', attributes: { starts_at: target.iso8601 }, client: initial)
    end.to raise_error(described_class::ProviderUnknown)

    fetch_started = Queue.new
    release_timeout = Queue.new
    slow = MutationCalendarFake.new(fetch_result: failure, on_fetch: lambda do
      fetch_started << true
      release_timeout.pop
    end)
    fast = MutationCalendarFake.new(fetch_result: {
                                      'id' => booking.provider_event_id, 'status' => 'confirmed',
                                      'start' => { 'dateTime' => target.iso8601 },
                                      'end' => { 'dateTime' => (target + 30.minutes).iso8601 }
                                    })
    outcome = Queue.new
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        outcome << AiLeadEmployee::BookingReconciliationService.new(
          account: account, user: user, booking: booking.reload, calendar_client: slow
        ).perform
      rescue StandardError => e
        outcome << e
      end
    end

    fetch_started.pop
    winner = AiLeadEmployee::BookingReconciliationService.new(
      account: account, user: user, booking: booking.reload, calendar_client: fast
    ).perform
    release_timeout << true
    Timeout.timeout(10) { worker.join }
    loser = outcome.pop

    expect(winner).to have_attributes(starts_at: target, provider_state: 'confirmed')
    expect(loser).to be_a(Booking)
    expect(loser.reload).to have_attributes(starts_at: target, provider_state: 'confirmed')
    expect(loser.provider_operation['state']).to eq('confirmed')
    expect(conversation.messages.outgoing.count).to eq(1)
  end

  it 'restores confirmed only when the live event exactly matches the frozen original event' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    target = Time.zone.parse('2026-09-21 10:00')
    expect do
      mutate('reschedule', key: 'still-original', attributes: { starts_at: target.iso8601 },
                           client: MutationCalendarFake.new(results: [failure]))
    end.to raise_error(described_class::ProviderUnknown)

    mutation = booking.reload.provider_operation
    expect(mutation).to include('original_starts_at' => '2026-09-21T09:00:00Z',
                                'original_ends_at' => '2026-09-21T09:30:00Z',
                                'original_provider_status' => 'confirmed')
    client = MutationCalendarFake.new(fetch_result: {
                                        'id' => booking.provider_event_id, 'status' => 'confirmed',
                                        'start' => { 'dateTime' => mutation['original_starts_at'] },
                                        'end' => { 'dateTime' => mutation['original_ends_at'] }
                                      })
    result = AiLeadEmployee::BookingReconciliationService.new(
      account: account, user: user, booking: booking, calendar_client: client
    ).perform

    expect(result).to have_attributes(starts_at: Time.zone.parse('2026-09-21 09:00'), provider_state: 'confirmed')
    expect(result.provider_operation['state']).to eq('not_applied')
    expect(conversation.messages.outgoing).to be_empty
  end

  it 'retains unknown for divergent or canceled provider events instead of inventing a local result' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    target = Time.zone.parse('2026-09-21 10:00')
    expect do
      mutate('reschedule', key: 'divergent-event', attributes: { starts_at: target.iso8601 },
                           client: MutationCalendarFake.new(results: [failure]))
    end.to raise_error(described_class::ProviderUnknown)

    [
      { 'status' => 'confirmed', 'start' => { 'dateTime' => '2026-09-21T11:00:00Z' },
        'end' => { 'dateTime' => '2026-09-21T11:30:00Z' } },
      { 'status' => 'cancelled', 'start' => { 'dateTime' => target.iso8601 },
        'end' => { 'dateTime' => (target + 30.minutes).iso8601 } }
    ].each do |event|
      client = MutationCalendarFake.new(fetch_result: event.merge('id' => booking.provider_event_id))
      expect do
        AiLeadEmployee::BookingReconciliationService.new(
          account: account, user: user, booking: booking.reload, calendar_client: client
        ).perform
      end.to raise_error(described_class::ProviderUnknown)
      expect(booking.reload).to have_attributes(starts_at: Time.zone.parse('2026-09-21 09:00'), provider_state: 'unknown',
                                                provider_error_code: 'provider_event_diverged')
    end
    expect(conversation.messages.outgoing).to be_empty
  end

  it 'treats an absent provider event as a conclusive cancel and emits one canonical notice' do
    timeout = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    expect do
      mutate('cancel', key: 'cancel-absent', attributes: { reason: 'Lead asked' },
                       client: MutationCalendarFake.new(results: [timeout]))
    end.to raise_error(described_class::ProviderUnknown)

    not_found = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'event_not_found', state: 'permission_error'
    )
    result = AiLeadEmployee::BookingReconciliationService.new(
      account: account, user: user, booking: booking,
      calendar_client: MutationCalendarFake.new(fetch_result: not_found)
    ).perform

    expect(result).to have_attributes(status: 'canceled', provider_state: 'canceled')
    expect(result.provider_operation['state']).to eq('confirmed')
    expect(conversation.messages.outgoing.count).to eq(1)
  end

  it 'rejects a different mutation while an uncertain provider operation awaits reconciliation' do
    booking.update!(provider_state: 'unknown', provider_operation: {
                      'action' => 'reschedule', 'state' => 'unknown', 'idempotency_key' => 'move-unknown',
                      'starts_at' => '2026-09-21T10:00:00Z', 'ends_at' => '2026-09-21T10:30:00Z'
                    })

    expect { mutate('cancel', key: 'cancel-different') }
      .to raise_error(described_class::ProviderRejected) do |error|
        expect(error.code).to eq('booking_provider_operation_unresolved')
      end
    expect(calendar.cancellations).to be_empty
    expect(conversation.messages.outgoing).to be_empty
  end

  it 'uses the after buffer at the rescheduled candidate end' do
    account.update!(settings: account.settings.deep_merge(
      'ai_lead_employee' => { 'booking' => {
        'buffer_before_minutes' => 5,
        'buffer_after_minutes' => 20
      } }
    ))
    create(:booking, account: account, calendar_id: booking.calendar_id,
                     starts_at: Time.zone.parse('2026-09-21T10:45:00Z'),
                     ends_at: Time.zone.parse('2026-09-21T11:15:00Z'))

    expect do
      mutate('reschedule', key: 'asymmetric-buffer', attributes: { starts_at: '2026-09-21T10:00:00Z' })
    end.to raise_error(described_class::SlotUnavailable)
    expect(calendar.updates).to be_empty
  end

  it 'rejects a reschedule checked under a replaced calendar and business-hours authority' do
    changing_calendar = MutationCalendarFake.new(on_free_busy: lambda do
      account.update!(settings: account.settings.deep_merge(
        'ai_lead_employee' => { 'booking' => {
          'calendar_id' => 'replacement-calendar',
          'allowed_hours' => { 'start' => '12:00', 'end' => '13:00' }
        } }
      ))
      connection.update!(calendar_id: 'replacement-calendar')
    end)

    expect do
      mutate('reschedule', key: 'changed-booking-authority',
                           attributes: { starts_at: '2026-09-21T10:00:00Z' }, client: changing_calendar)
    end.to raise_error(described_class::ProviderRejected) do |error|
      expect(error.code).to eq('booking_configuration_changed_retry')
    end
    expect(changing_calendar.updates).to be_empty
  end

  it 'does not deadlock mutation state against a real qualification evidence writer' do
    offer = AiLeadEmployee::Offer.create!(
      account: account, name: 'Writer race', currency: 'TZS', enabled: true, configuration_version: 1,
      configuration: {
        'qualification_mode' => 'enabled', 'next_step' => { 'kind' => 'sales_call' },
        'questions' => [], 'rules' => [], 'score_weights' => {},
        'score_thresholds' => { 'qualified' => 0, 'highly_qualified' => 100 }
      }
    )
    conversation.update!(offer: offer)
    barrier = Queue.new
    outcomes = Queue.new
    workers = [
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          outcomes << begin
            AiLeadEmployee::OfferHumanEvidenceWriter.new(
              conversation: conversation.reload, offer: offer.reload, user: user,
              field_key: 'problem', value: 'Needs faster follow-up'
            ).perform
            :evidence_written
          rescue StandardError => e
            e
          end
        end
      end,
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.pop
          outcomes << begin
            mutate('cancel', key: 'qualification-writer-race')
            :booking_canceled
          rescue StandardError => e
            e
          end
        end
      end
    ]
    2.times { barrier << true }
    Timeout.timeout(10) { workers.each(&:join) }
    results = Array.new(2) { outcomes.pop }

    expect(results).to contain_exactly(:evidence_written, :booking_canceled)
    expect(results.grep(ActiveRecord::Deadlocked)).to be_empty
  end

  it 'keeps the old local time and reports unknown if the target is claimed after Google updates' do
    competing = nil
    client = MutationCalendarFake.new(on_update: lambda do |desired|
      competing = create(:booking, account: account, calendar_id: booking.calendar_id,
                                   starts_at: desired.starts_at, ends_at: desired.ends_at)
    end)

    travel_to Time.zone.parse('2026-09-19 06:00') do
      expect do
        mutate('reschedule', key: 'move-raced', attributes: { starts_at: '2026-09-21T10:00:00Z' }, client: client)
      end.to raise_error(described_class::ProviderUnknown)
    end

    expect(booking.reload).to have_attributes(starts_at: Time.zone.parse('2026-09-21 09:00'), provider_state: 'unknown')
    expect(booking.provider_operation).to include('state' => 'unknown',
                                                  'error_code' => 'local_slot_conflict_after_provider_update')
    expect(competing).to be_persisted
    expect(conversation.messages.outgoing).to be_empty
  end

  it 'inspects the provider but retains unknown when booking authority changed after Google updated' do
    client = MutationCalendarFake.new(on_update: lambda do |_desired|
      account.update!(settings: account.settings.deep_merge(
        'ai_lead_employee' => { 'booking' => { 'allowed_hours' => { 'start' => '12:00', 'end' => '13:00' } } }
      ))
    end)

    expect do
      mutate('reschedule', key: 'authority-changed-after-update',
                           attributes: { starts_at: '2026-09-21T10:00:00Z' }, client: client)
    end.to raise_error(described_class::ProviderUnknown)
    expect(booking.reload).to have_attributes(starts_at: Time.zone.parse('2026-09-21 09:00'), provider_state: 'unknown',
                                              provider_error_code: 'booking_configuration_changed_after_provider_update')

    expect do
      AiLeadEmployee::BookingReconciliationService.new(
        account: account, user: user, booking: booking, calendar_client: client
      ).perform
    end.to raise_error(described_class::ProviderUnknown)
    expect(client.updates.size).to eq(1)
    expect(client.fetches.size).to eq(1)
    expect(booking.reload).to have_attributes(starts_at: Time.zone.parse('2026-09-21 09:00'), provider_state: 'unknown',
                                              provider_error_code: 'booking_configuration_changed_after_provider_update')
  end

  it 'does not let a late same-key timeout downgrade a conclusive reschedule' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    winner = MutationCalendarFake.new
    loser = MutationCalendarFake.new(results: [failure], on_update: lambda do |_desired|
      mutate('reschedule', key: 'same-key-race', attributes: { starts_at: '2026-09-21T10:00:00Z' }, client: winner)
    end)

    result = mutate('reschedule', key: 'same-key-race', attributes: { starts_at: '2026-09-21T10:00:00Z' }, client: loser)

    expect(result.reload).to have_attributes(starts_at: Time.zone.parse('2026-09-21 10:00'), provider_state: 'confirmed')
    expect(result.calendar_event_payload.dig('mutations', 'same-key-race', 'state')).to eq('confirmed')
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, RSpec/InstanceVariable, RSpec/LeakyConstantDeclaration
# rubocop:enable Style/MultilineBlockChain
