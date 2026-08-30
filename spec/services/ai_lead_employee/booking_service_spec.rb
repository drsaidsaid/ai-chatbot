# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::BookingService do
  let(:account) do
    create(
      :account,
      settings: {
        'ai_lead_employee' => {
          'booking' => {
            'connected' => true,
            'provider' => 'local_calendar',
            'calendar_id' => 'sales',
            'timezone' => 'Africa/Dar_es_Salaam',
            'working_days' => [1],
            'allowed_hours' => { 'start' => '09:00', 'end' => '10:00' },
            'duration_minutes' => 30,
            'buffer_before_minutes' => 0,
            'buffer_after_minutes' => 0,
            'minimum_notice_minutes' => 60
          },
          'alert_routes' => {
            described_class::PREPARATION_ALERT_TYPE => [{ 'type' => 'assignee' }]
          }
        }
      }
    )
  end
  let(:operator) { create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '255700000001' }) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: {
        'api_key' => 'test-key',
        'phone_number_id' => '111222333',
        'business_account_id' => '444555666',
        'source' => 'embedded_signup'
      }
    )
  end
  let(:contact) { create(:contact, account: account, name: 'Jane Lead', phone_number: '+255712345678', email: 'jane@example.test') }
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, contact: contact, source_id: '255712345678') }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      assignee: operator,
      control_state: :ai_active,
      control_version: 3
    )
  end
  let!(:problem_evidence) { create(:qualification_evidence, account: account, contact: contact, conversation: conversation, signal: :problem) }
  let(:qualification) do
    create(
      :lead_qualification,
      account: account,
      contact: contact,
      quality: :highly_qualified,
      follow_up_state: :human_review,
      score: 90,
      reasons: ['Problem: need more leads', 'Urgency: urgent'],
      evidence_snapshot: {
        'problem' => { 'value' => 'need more leads', 'evidence_id' => problem_evidence.id },
        'urgency' => { 'value' => 'urgent' },
        'budget' => { 'value' => '$2500' },
        'decision_authority' => { 'value' => 'owner' }
      }
    )
  end
  let(:starts_at) { Time.zone.parse('2026-08-31T06:00:00Z') }

  before do
    stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .to_return(
        status: 200,
        body: { messages: [{ id: "wamid.#{SecureRandom.hex(4)}" }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'creates a durable booking, confirms the lead through the CE sender path, sends one optional calendar invite, and alerts the operator' do # rubocop:disable RSpec/MultipleExpectations
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      result = nil
      perform_enqueued_jobs(only: SendReplyJob) do
        result = described_class.new(
          conversation: conversation,
          qualification: qualification,
          starts_at: starts_at,
          idempotency_key: 'booking-key-1'
        ).perform
      end

      booking = result.booking
      confirmation_message = Message.find(booking.confirmation_message_id)
      preparation_delivery = booking.preparation_alert_deliveries.first
      preparation_message = Message.find(preparation_delivery['message_id'])

      expect(result.created).to be(true)
      expect(booking).to have_attributes(
        contact: contact,
        conversation: conversation,
        lead_qualification: qualification,
        assignee: operator,
        starts_at: starts_at,
        ends_at: starts_at + 30.minutes,
        timezone: 'Africa/Dar_es_Salaam',
        calendar_invitation_sent_at: be_present
      )
      expect(booking.qualification_evidence_ids).to contain_exactly(problem_evidence.id)
      expect(booking.provider_event_id).to eq("booking-#{booking.id}")
      expect(booking.confirmation_message_id).to be_present
      expect(booking.preparation_alert_recipients).to eq(['255700000001'])
      expect(booking.preparation_alert_deliveries).to all(include('status' => 'queued'))
      expect(qualification.reload).to be_call_booked
      expect(conversation.reload).to have_attributes(control_state: 'human_active', control_version: 4)
      expect(confirmation_message).to have_attributes(conversation: conversation, private: false, message_type: 'outgoing')
      expect(confirmation_message.content).to include('Your call is booked for Monday, August 31 at 9:00 AM EAT')
      expect(confirmation_message.additional_attributes.dig('ai_lead_employee', 'delivery_boundary')).to eq('outbox')
      expect(preparation_message.additional_attributes.dig('ai_lead_employee', 'delivery_boundary')).to eq('outbox')
      expect(preparation_message.additional_attributes.dig('ai_lead_employee', 'booking_id')).to eq(booking.id)
      expect(performed_jobs.pluck(:job)).to include(SendReplyJob)
    end
  end

  it 'does not send a calendar invitation when the Lead has not supplied email' do
    contact.update!(email: nil)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      booking = described_class.new(
        conversation: conversation,
        qualification: qualification,
        starts_at: starts_at,
        idempotency_key: 'booking-key-no-email'
      ).perform.booking

      expect(booking.calendar_invitation_sent_at).to be_nil
      expect(booking.calendar_event_payload['invitee_email']).to be_nil
    end
  end

  it 'deduplicates retries without duplicating calendar events, confirmations, or alerts' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      perform_enqueued_jobs(only: SendReplyJob) do
        described_class.new(conversation: conversation, qualification: qualification, starts_at: starts_at, idempotency_key: 'retry-key').perform
      end

      expect do
        perform_enqueued_jobs(only: SendReplyJob) do
          result = described_class.new(
            conversation: conversation.reload,
            qualification: qualification.reload,
            starts_at: starts_at,
            idempotency_key: 'retry-key'
          ).perform
          expect(result.created).to be(false)
        end
      end.not_to change(Booking, :count)

      expect(Message.outgoing.count).to eq(2)
      expect(Booking.last.preparation_alert_deliveries.count).to eq(1)
    end
  end

  it 'recovers a legacy provider confirmation id through a durable local message' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      booking = described_class.new(
        conversation: conversation,
        qualification: qualification,
        starts_at: starts_at,
        idempotency_key: 'legacy-confirmation-key'
      ).perform.booking
      booking.update!(confirmation_message_id: 'wamid.legacy-provider-id')

      expect do
        described_class.new(
          conversation: conversation.reload,
          qualification: qualification.reload,
          starts_at: starts_at,
          idempotency_key: 'legacy-confirmation-key'
        ).perform
      end.to change(Message.outgoing, :count).by(1)

      expect(booking.reload.confirmation_message_id).to match(/\A\d+\z/)
    end
  end

  it 'adds configured WhatsApp template params to preparation alert messages' do
    channel.update!(
      message_templates: [
        {
          'name' => 'booking_preparation',
          'status' => 'APPROVED',
          'category' => 'UTILITY',
          'language' => 'en',
          'parameter_format' => 'NAMED',
          'components' => [
            {
              'type' => 'BODY',
              'text' => 'Booking prep {{contact}} {{booking_time}} {{problem}} {{budget}}'
            }
          ]
        }
      ]
    )
    account.update!(
      settings: account.settings.deep_merge(
        'ai_lead_employee' => {
          'alert_templates' => {
            described_class::PREPARATION_ALERT_TYPE => {
              'name' => 'booking_preparation',
              'language' => 'en',
              'processed_params' => {}
            }
          }
        }
      )
    )

    booking = nil
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      booking = described_class.new(
        conversation: conversation,
        qualification: qualification,
        starts_at: starts_at,
        idempotency_key: 'booking-template-key'
      ).perform.booking
    end

    preparation_message = Message.find(booking.preparation_alert_deliveries.first['message_id'])
    template_params = preparation_message.additional_attributes['template_params']
    expect(template_params).to include('name' => 'booking_preparation', 'language' => 'en')
    expect(template_params.dig('processed_params', 'body')).to include(
      'contact' => 'Jane Lead +255712345678 jane@example.test',
      'booking_time' => 'Monday, August 31 at 9:00 AM EAT',
      'problem' => 'need more leads',
      'budget' => '$2500'
    )
  end

  it 'rejects concurrent overlapping attempts at the database boundary' do
    create(:booking, account: account, calendar_id: 'sales', starts_at: starts_at + 15.minutes, ends_at: starts_at + 45.minutes)

    expect do
      create(:booking, account: account, calendar_id: 'sales', starts_at: starts_at, ends_at: starts_at + 30.minutes)
    end.to raise_error(ActiveRecord::RecordInvalid, /overlaps an active booking/)
  end

  it 'rejects a slot already held by another active booking' do
    create(:booking, account: account, calendar_id: 'sales', starts_at: starts_at, ends_at: starts_at + 30.minutes)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect do
        described_class.new(conversation: conversation, qualification: qualification, starts_at: starts_at, idempotency_key: 'conflict-key').perform
      end.to raise_error(described_class::SlotUnavailable)
    end
  end

  it 'rejects a buffer-adjacent active booking through serialized availability checks' do
    account.update!(
      settings: account.settings.deep_merge(
        'ai_lead_employee' => {
          'booking' => {
            'buffer_after_minutes' => 15
          }
        }
      )
    )
    create(:booking, account: account, calendar_id: 'sales', starts_at: starts_at, ends_at: starts_at + 30.minutes)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect do
        described_class.new(
          conversation: conversation,
          qualification: qualification,
          starts_at: starts_at + 30.minutes,
          idempotency_key: 'buffer-conflict-key'
        ).perform
      end.to raise_error(described_class::SlotUnavailable)
    end
  end

  it 'rejects an overlapping active booking even when the selected start time differs' do
    create(:booking, account: account, calendar_id: 'sales', starts_at: starts_at + 15.minutes, ends_at: starts_at + 45.minutes)

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      expect do
        described_class.new(conversation: conversation, qualification: qualification, starts_at: starts_at, idempotency_key: 'overlap-key').perform
      end.to raise_error(described_class::SlotUnavailable)
    end
  end

  it 'does not book a Lead that is not Highly Qualified' do
    qualification.update!(quality: :qualified)

    expect do
      described_class.new(conversation: conversation, qualification: qualification, starts_at: starts_at, idempotency_key: 'not-hot').perform
    end.to raise_error(described_class::NotHighlyQualified)
  end
end
