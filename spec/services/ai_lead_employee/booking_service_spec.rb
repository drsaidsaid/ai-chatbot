# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

# Stateful provider behavior and the full booking aggregate require shared fixtures and aggregate assertions.
# rubocop:disable Lint/ConstantDefinitionInBlock, RSpec/InstanceVariable, RSpec/LeakyConstantDeclaration
# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/MultipleMemoizedHelpers, Style/MultilineBlockChain

RSpec.describe AiLeadEmployee::BookingService do
  class CalendarFake
    attr_reader :created_bookings

    def initialize(create_results: [], free_busy_result: nil, on_create: nil, on_free_busy: nil)
      @create_results = create_results
      @free_busy_result = free_busy_result
      @on_create = on_create
      @on_free_busy = on_free_busy
      @created_bookings = []
    end

    def free_busy(**)
      @on_free_busy&.call
      @free_busy_result ||
        AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(busy_slots: [], state: 'connected', error_code: nil)
    end

    def create_event!(booking:)
      created_bookings << booking
      @on_create&.call(booking)
      result = @create_results.shift
      raise result if result.is_a?(Exception)

      result || {
        'provider_event_id' => AiLeadEmployee::GoogleCalendarClient.event_id_for(booking),
        'provider' => 'google_calendar',
        'calendar_id' => booking.calendar_id,
        'calendar_state' => 'confirmed',
        'invitee_email' => booking.attendee_email
      }.compact
    end
  end

  before do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(true)
    proposal_message
    agreement_message
    agreement_evidence

    stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
      .to_return(status: 200, body: { messages: [{ id: 'wamid.BOOKING.CONFIRMED' }] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  let(:account) do
    create(:account, settings: { 'ai_lead_employee' => { 'booking' => {
             'timezone' => 'Africa/Dar_es_Salaam', 'working_days' => [1],
             'allowed_hours' => { 'start' => '09:00', 'end' => '10:00' },
             'duration_minutes' => 30, 'minimum_notice_minutes' => 60
           } } })
  end
  let!(:connection) do
    create(:google_calendar_connection, account: account, status: :connected, access_token: nil, refresh_token: nil)
  end
  let(:operator) { create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '255700000001' }) }
  let!(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false,
                              validate_provider_config: false,
                              provider_config: { 'api_key' => 'test-key', 'phone_number_id' => '111222333',
                                                 'business_account_id' => '444555666', 'source' => 'embedded_signup' })
  end
  let(:contact) { create(:contact, account: account, name: 'Jane Lead', phone_number: '+255712345678', email: 'stored@example.test') }
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, contact: contact, source_id: '255712345678') }
  let(:offer) do
    AiLeadEmployee::Offer.create!(account: account, name: 'Free fit call', currency: 'TZS', enabled: true,
                                  configuration_version: 1, configuration: {
                                    'qualification_mode' => 'enabled', 'next_step' => { 'kind' => 'sales_call' },
                                    'questions' => [], 'rules' => [], 'score_weights' => {},
                                    'score_thresholds' => { 'qualified' => 0, 'highly_qualified' => 100 }
                                  })
  end
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          assignee: operator, offer: offer, control_state: :ai_active, control_version: 3)
  end
  let(:problem_evidence) do
    create(:qualification_evidence, account: account, contact: contact, conversation: conversation, offer: offer,
                                    field_key: 'problem', value: { 'value' => 'need more leads' })
  end
  let(:proposal_message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: operator,
                     message_type: :outgoing, content: 'Would Monday at 9 work?',
                     additional_attributes: {
                       ai_lead_employee: { booking_proposal: {
                         idempotency_key: 'proposal', starts_at: starts_at.iso8601,
                         ends_at: (starts_at + 30.minutes).iso8601, offer_id: offer.id,
                         offer_configuration_version: offer.configuration_version
                       } }
                     })
  end
  let(:agreement_evidence) do
    create(:qualification_evidence, account: account, contact: contact, conversation: conversation, offer: offer,
                                    message: agreement_message, field_key: 'sales_call_agreement', source: :human,
                                    value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
                                             'agreed_starts_at' => starts_at.iso8601,
                                             'proposal_message_id' => proposal_message.id,
                                             'offer_configuration_version' => offer.configuration_version })
  end
  let(:agreement_message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Monday at 9 works for me',
                     provider_created_at: starts_at - 2.hours, created_at: starts_at - 2.hours,
                     updated_at: starts_at - 2.hours)
  end
  let(:qualification) do
    create(:lead_qualification, account: account, contact: contact, offer: offer, quality: :qualified,
                                configuration_version: offer.configuration_version,
                                assessment: { 'fit' => { 'status' => 'met' }, 'readiness' => { 'status' => 'met' },
                                              'action_eligibility' => { 'status' => 'met' } },
                                evidence_snapshot: { 'problem' => { 'value' => 'need more leads',
                                                                    'evidence_id' => problem_evidence.id } })
  end
  let(:starts_at) { Time.zone.parse('2026-08-31T06:00:00Z') }
  let(:calendar) { CalendarFake.new }

  def perform_booking(key: 'booking-key', attendee_email: nil, agreed_time: starts_at, client: calendar)
    described_class.new(conversation: conversation, qualification: qualification, starts_at: starts_at,
                        agreed_starts_at: agreed_time, agreement_message: agreement_message,
                        attendee_email: attendee_email, idempotency_key: key, calendar_client: client).perform
  end

  it 'confirms one durable provider event before queuing confirmation and preparation messages' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      result = perform_booking(attendee_email: 'voluntary@example.test')
      booking = result.booking

      expect(result.created).to be(true)
      expect(booking).to have_attributes(status: 'confirmed', provider_state: 'confirmed', offer: offer,
                                         agreement_evidence: agreement_evidence, agreement_message: agreement_message,
                                         attendee_email: 'voluntary@example.test', calendar_invitation_sent_at: be_present)
      expect(booking.provider_event_id).to eq(AiLeadEmployee::GoogleCalendarClient.event_id_for(booking))
      expect(booking.qualification_evidence_ids).to contain_exactly(problem_evidence.id, agreement_evidence.id)
      expect(qualification.reload).to be_call_booked
      expect(conversation.reload).to have_attributes(control_state: 'human_active', control_version: 5)
      expect(Message.find(booking.confirmation_message_id).content).to include('Monday, August 31 at 9:00 AM EAT')
      expect(booking.preparation_alert_deliveries.size).to eq(1)
      alert = account.messages.find(booking.preparation_alert_deliveries.sole.fetch('message_id'))
      expect(alert.content).to include(
        "/app/accounts/#{account.id}/conversations/#{conversation.display_id}?queue=bookings",
        "Owner: #{operator.name}"
      )
    end
  end

  it 'never infers an attendee email from the stored contact email' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      booking = perform_booking(key: 'no-email').booking
      expect(booking).to have_attributes(attendee_email: nil, calendar_invitation_sent_at: nil)
      expect(booking.calendar_event_payload['invitee_email']).to be_nil
    end
  end

  it 'dispatches the single confirmed-booking message through canonical WhatsApp authority after human handoff' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      booking = perform_booking(key: 'dispatch-confirmation').booking
      confirmation = Message.find(booking.confirmation_message_id)

      SendReplyJob.perform_now(confirmation.id)

      expect(confirmation.reload.whatsapp_outbound_delivery).to have_attributes(state: 'accepted', failure_code: nil)
      expect(confirmation.source_id).to eq('wamid.BOOKING.CONFIRMED')
      expect(conversation.reload).to be_human_active
    end
  end

  it 'deduplicates confirmed retries and rejects reuse with a different payload' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      perform_booking(key: 'retry')
      expect(perform_booking(key: 'retry').created).to be(false)
      expect(calendar.created_bookings.size).to eq(1)
      expect(Booking.count).to eq(1)
      expect(Message.outgoing.count).to eq(3)

      expect { perform_booking(key: 'retry', attendee_email: 'different@example.test') }
        .to raise_error(described_class::Ineligible) { |error| expect(error.code).to eq('idempotency_key_payload_mismatch') }
    end
  end

  it 'records an uncertain provider result without presenting a confirmation, then reconciles by deterministic retry' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(error_code: 'provider_timeout', state: 'connection_error')
    client = CalendarFake.new(create_results: [failure, nil])

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(key: 'unknown', client: client) }.to raise_error(described_class::ProviderUnknown)
      booking = Booking.find_by!(idempotency_key: 'unknown')
      expect(booking).to have_attributes(status: 'provider_unknown', provider_state: 'unknown', confirmation_message_id: nil)
      expect(qualification.reload).not_to be_call_booked
      expect(Message.outgoing.count).to eq(1)

      reconciled = AiLeadEmployee::BookingReconciliationService.new(
        account: account, user: operator, booking: booking, calendar_client: client
      ).perform
      expect(reconciled).to have_attributes(status: 'confirmed', provider_state: 'confirmed')
      expect(Message.outgoing.count).to eq(3)
      expect(client.created_bookings.map(&:id)).to eq([booking.id, booking.id])
    end
  end

  it 'requires the source agreement to name the exact requested start time' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(agreed_time: starts_at + 30.minutes) }
        .to raise_error(described_class::Ineligible) { |error| expect(error.code).to eq('specific_agreed_time_required') }
    end
  end

  it 'requires the submitted incoming Message to be the source of the agreement evidence' do
    other_message = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                                     message_type: :incoming, content: 'A different reply')

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect do
        described_class.new(
          conversation: conversation, qualification: qualification, starts_at: starts_at,
          agreed_starts_at: starts_at, agreement_message: other_message,
          idempotency_key: 'wrong-source', calendar_client: calendar
        ).perform
      end.to raise_error(described_class::Ineligible) do |error|
        expect(error.code).to eq('lead_agreement_message_required')
      end
    end
  end

  it 'rejects stale Offer qualification even when the Lead is globally Highly Qualified' do
    qualification.update!(quality: :highly_qualified, configuration_version: offer.configuration_version - 1)
    expect { perform_booking }.to raise_error(described_class::Ineligible) do |error|
      expect(error.code).to eq('offer_eligibility_not_met')
    end
  end

  it 'holds provider-unknown slots against competing bookings' do
    create(:booking, account: account, calendar_id: 'primary', starts_at: starts_at, ends_at: starts_at + 30.minutes,
                     status: :provider_unknown)
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(key: 'conflict') }.to raise_error(described_class::SlotUnavailable)
    end
  end

  it 'uses the after buffer at the candidate end when reserving against local bookings' do
    account.update!(settings: account.settings.deep_merge(
      'ai_lead_employee' => { 'booking' => {
        'buffer_before_minutes' => 5,
        'buffer_after_minutes' => 20
      } }
    ))
    create(:booking, account: account, calendar_id: 'primary',
                     starts_at: starts_at + 45.minutes, ends_at: starts_at + 75.minutes)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(key: 'asymmetric-buffer') }.to raise_error(described_class::SlotUnavailable)
    end
  end

  it 'surfaces a Calendar access failure instead of presenting it as an unavailable slot' do
    failed_availability = AiLeadEmployee::BookingCalendarClient::FreeBusyResult.new(
      busy_slots: [], state: 'permission_error', error_code: 'insufficient_permissions'
    )
    failed_calendar = CalendarFake.new(free_busy_result: failed_availability)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(key: 'permission-error', client: failed_calendar) }
        .to raise_error(described_class::Ineligible) do |error|
          expect(error.code).to eq('insufficient_permissions')
        end
    end
    expect(Booking.find_by(idempotency_key: 'permission-error')).to be_nil
  end

  it 'serializes simultaneous requests so only one provider event can own the slot' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      conversation
      qualification
      agreement_message
      barrier = Queue.new
      outcomes = Queue.new
      workers = %w[concurrent-a concurrent-b].map do |key|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            outcomes << begin
              perform_booking(key: key)
              :confirmed
            rescue described_class::SlotUnavailable
              :unavailable
            end
          end
        end
      end
      2.times { barrier << true }
      workers.each(&:join)

      expect(Array.new(2) { outcomes.pop }).to contain_exactly(:confirmed, :unavailable)
      expect(Booking.active.count).to eq(1)
      expect(calendar.created_bookings.size).to eq(1)
    end
  end

  it 'serializes different starts whose configured buffers overlap beyond the raw database ranges' do
    account.update!(settings: account.settings.deep_merge(
      'ai_lead_employee' => { 'booking' => {
        'allowed_hours' => { 'start' => '09:00', 'end' => '11:00' },
        'buffer_before_minutes' => 10,
        'buffer_after_minutes' => 10
      } }
    ))
    second_start = starts_at + 30.minutes
    second_contact = create(:contact, account: account, phone_number: '+255712345679')
    second_contact_inbox = create(:contact_inbox, inbox: channel.inbox, contact: second_contact, source_id: '255712345679')
    second_conversation = create(
      :conversation, account: account, inbox: channel.inbox, contact: second_contact,
                     contact_inbox: second_contact_inbox, assignee: operator, offer: offer
    )
    second_qualification = create(
      :lead_qualification, account: account, contact: second_contact, offer: offer, quality: :qualified,
                           configuration_version: offer.configuration_version,
                           assessment: { 'fit' => { 'status' => 'met' }, 'readiness' => { 'status' => 'met' },
                                         'action_eligibility' => { 'status' => 'met' } }
    )
    second_proposal = create(
      :message, account: account, inbox: channel.inbox, conversation: second_conversation, sender: operator,
                message_type: :outgoing, content: 'Would Monday at 9:30 work?', additional_attributes: {
                  ai_lead_employee: { booking_proposal: {
                    idempotency_key: 'second-proposal', starts_at: second_start.iso8601,
                    ends_at: (second_start + 30.minutes).iso8601, offer_id: offer.id,
                    offer_configuration_version: offer.configuration_version
                  } }
                }
    )
    second_agreement = create(
      :message, account: account, inbox: channel.inbox, conversation: second_conversation, sender: second_contact,
                message_type: :incoming, content: 'Yes, 9:30 works'
    )
    create(
      :qualification_evidence, account: account, contact: second_contact, conversation: second_conversation,
                               offer: offer, message: second_agreement, field_key: 'sales_call_agreement', source: :human,
                               value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
                                        'agreed_starts_at' => second_start.iso8601, 'proposal_message_id' => second_proposal.id,
                                        'offer_configuration_version' => offer.configuration_version }
    )

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      barrier = Queue.new
      outcomes = Queue.new
      workers = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            outcomes << begin
              perform_booking(key: 'buffer-race-first')
              :confirmed
            rescue described_class::SlotUnavailable
              :unavailable
            end
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            outcomes << begin
              described_class.new(
                conversation: second_conversation, qualification: second_qualification, starts_at: second_start,
                agreed_starts_at: second_start, agreement_message: second_agreement,
                idempotency_key: 'buffer-race-second', calendar_client: calendar
              ).perform
              :confirmed
            rescue described_class::SlotUnavailable
              :unavailable
            end
          end
        end
      ]
      2.times { barrier << true }
      workers.each(&:join)

      expect(Array.new(2) { outcomes.pop }).to contain_exactly(:confirmed, :unavailable)
      expect(Booking.active.count).to eq(1)
      expect(calendar.created_bookings.size).to eq(1)
    end
  end

  it 'does not deadlock PostgreSQL slot reservation against an Offer revision write' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      conversation
      qualification
      agreement_message
      writer_attributes = offer.payload.slice(
        'name', 'currency', 'enabled', 'version', 'qualification_mode', 'next_step', 'questions', 'budget_ranges',
        'rules', 'score_weights', 'score_thresholds'
      )
      barrier = Queue.new
      outcomes = Queue.new
      workers = [
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            outcomes << begin
              AiLeadEmployee::OfferConfigurationWriter.new(offer: offer.reload, attributes: writer_attributes).perform
              :offer_revised
            rescue StandardError => e
              e
            end
          end
        end,
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            barrier.pop
            outcomes << begin
              perform_booking(key: 'offer-revision-race')
              :booking_confirmed
            rescue described_class::Ineligible
              :booking_rejected_stale
            rescue StandardError => e
              e
            end
          end
        end
      ]
      2.times { barrier << true }
      Timeout.timeout(10) { workers.each(&:join) }
      results = Array.new(2) { outcomes.pop }

      expect(results).to include(:offer_revised)
      expect(results.grep(ActiveRecord::Deadlocked)).to be_empty
      expect(results & %i[booking_confirmed booking_rejected_stale]).not_to be_empty
    end
  end

  it 'does not let a late same-key provider timeout downgrade a conclusive confirmation' do
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    winner = CalendarFake.new
    loser = CalendarFake.new(create_results: [failure], on_create: lambda do |_booking|
      perform_booking(key: 'same-key-race', client: winner)
    end)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      result = perform_booking(key: 'same-key-race', client: loser)
      expect(result.booking.reload).to have_attributes(status: 'confirmed', provider_state: 'confirmed')
    end
  end

  it 'revalidates the locked Offer revision after provider availability returns' do
    changing_calendar = CalendarFake.new(on_free_busy: lambda do
      offer.update!(configuration_version: offer.configuration_version + 1)
    end)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(key: 'stale-authority', client: changing_calendar) }
        .to raise_error(described_class::Ineligible) do |error|
          expect(error.code).to eq('offer_eligibility_not_met')
        end
    end
    expect(Booking.find_by(idempotency_key: 'stale-authority')).to be_nil
  end

  it 'rejects availability checked under a replaced calendar and business-hours authority' do
    changing_calendar = CalendarFake.new(on_free_busy: lambda do
      account.update!(settings: account.settings.deep_merge(
        'ai_lead_employee' => { 'booking' => {
          'calendar_id' => 'replacement-calendar',
          'allowed_hours' => { 'start' => '12:00', 'end' => '13:00' }
        } }
      ))
      connection.update!(calendar_id: 'replacement-calendar')
    end)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect { perform_booking(key: 'changed-booking-authority', client: changing_calendar) }
        .to raise_error(described_class::Ineligible) do |error|
          expect(error.code).to eq('booking_configuration_changed_retry')
        end
    end
    expect(Booking.find_by(idempotency_key: 'changed-booking-authority')).to be_nil
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock, RSpec/InstanceVariable, RSpec/LeakyConstantDeclaration
# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations, RSpec/MultipleMemoizedHelpers, Style/MultilineBlockChain
