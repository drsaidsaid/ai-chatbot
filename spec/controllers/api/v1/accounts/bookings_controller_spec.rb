# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bookings API', type: :request do
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
            'allowed_hours' => { 'start' => '09:00', 'end' => '10:00' },
            'duration_minutes' => 30,
            'minimum_notice_minutes' => 60
          }
        }
      }
    )
  end
  let(:agent) { create(:user, account: account, role: :agent, custom_attributes: { 'whatsapp_alert_phone' => '255700000001' }) }
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
  let(:contact) { create(:contact, account: account, phone_number: '+255712345678') }
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, contact: contact, source_id: '255712345678') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox, assignee: agent)
  end

  before do
    create(
      :lead_qualification,
      account: account,
      contact: conversation.contact,
      quality: :highly_qualified,
      evidence_snapshot: {
        'problem' => { 'value' => 'need more leads' },
        'urgency' => { 'value' => 'urgent' },
        'budget' => { 'value' => '$2500' },
        'decision_authority' => { 'value' => 'owner' }
      }
    )
    stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .to_return(status: 200, body: { messages: [{ id: 'wamid.BOOKING' }] }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'returns available slots' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      get "/api/v1/accounts/#{account.id}/bookings/available_slots",
          headers: agent.create_new_auth_token,
          params: { from: Time.current.iso8601, days: 1 },
          as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['slots']).to include('2026-08-31T06:00:00Z')
    end
  end

  it 'creates a booking for a Highly Qualified Lead' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      post "/api/v1/accounts/#{account.id}/bookings",
           headers: agent.create_new_auth_token,
           params: {
             conversation_id: conversation.id,
             starts_at: '2026-08-31T06:00:00Z',
             idempotency_key: 'request-key'
           },
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        'conversation_id' => conversation.id,
        'assignee_id' => agent.id,
        'status' => 'confirmed',
        'calendar_id' => 'sales'
      )
    end
  end

  it 'lists tenant-scoped agenda bookings with detail, calendar, availability, and filters' do
    booking = create(
      :booking,
      account: account,
      contact: contact,
      conversation: conversation,
      assignee: agent,
      lead_qualification: contact.lead_qualification,
      calendar_id: 'sales',
      provider_event_id: 'booking-provider-1',
      confirmation_message_id: 'wamid.confirmed',
      calendar_invitation_sent_at: Time.zone.parse('2026-08-26T08:15:00Z'),
      starts_at: Time.zone.parse('2026-08-27T11:30:00Z'),
      ends_at: Time.zone.parse('2026-08-27T12:00:00Z'),
      timezone: 'Africa/Dar_es_Salaam',
      preparation_alert_deliveries: [{ 'status' => 'sent' }],
      calendar_event_payload: { 'preparation_state' => 'ready' },
      qualification_snapshot: {
        'offer' => 'Product Demo',
        'quality' => 'highly_qualified',
        'evidence' => {
          'problem' => { 'value' => 'needs WhatsApp follow up' }
        }
      }
    )
    other_account = create(:account)
    create(:booking, account: other_account)

    get "/api/v1/accounts/#{account.id}/bookings",
        headers: agent.create_new_auth_token,
        params: {
          from: '2026-08-24T00:00:00Z',
          booking_id: booking.id,
          offer: 'Product Demo'
        },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['bookings'].pluck('id')).to eq([booking.id])
    expect(response.parsed_body['selected_booking']).to include(
      'id' => booking.id,
      'whatsapp_state' => 'confirmed',
      'calendar_state' => 'confirmed',
      'preparation_state' => 'ready'
    )
    expect(response.parsed_body['selected_booking']['detail']['strongest_evidence'].first).to include('value' => 'needs WhatsApp follow up')
    expect(response.parsed_body['calendar'].first['bookings'].first['id']).to eq(booking.id)
    expect(response.parsed_body['availability']).to include('provider_state' => 'connected')
    expect(response.parsed_body['filter_options']['offers']).to include('Product Demo')
  end

  it 'limits agenda bookings to the selected date range' do
    in_range = create(
      :booking,
      account: account,
      assignee: agent,
      starts_at: Time.zone.parse('2026-08-27T11:30:00Z'),
      ends_at: Time.zone.parse('2026-08-27T12:00:00Z')
    )
    create(
      :booking,
      account: account,
      assignee: agent,
      starts_at: Time.zone.parse('2040-01-01T11:30:00Z'),
      ends_at: Time.zone.parse('2040-01-01T12:00:00Z')
    )

    get "/api/v1/accounts/#{account.id}/bookings",
        headers: agent.create_new_auth_token,
        params: { from: '2026-08-24T00:00:00Z' },
        as: :json

    expect(response.parsed_body['bookings'].pluck('id')).to eq([in_range.id])
  end

  it 'limits non-admin operators to their assigned bookings' do
    assigned_booking = create(:booking, account: account, assignee: agent)
    create(
      :booking,
      account: account,
      assignee: create(:user, account: account, role: :agent),
      starts_at: assigned_booking.starts_at + 1.hour,
      ends_at: assigned_booking.ends_at + 1.hour
    )

    get "/api/v1/accounts/#{account.id}/bookings",
        headers: agent.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['bookings'].pluck('id')).to eq([assigned_booking.id])
  end

  it 'reschedules once for an idempotency key and records provider, WhatsApp, Follow-up, and audit state' do
    booking = create(
      :booking,
      account: account,
      contact: contact,
      conversation: conversation,
      assignee: agent,
      lead_qualification: contact.lead_qualification,
      calendar_id: 'sales',
      starts_at: Time.zone.parse('2026-08-31T06:00:00Z'),
      ends_at: Time.zone.parse('2026-08-31T06:30:00Z')
    )

    2.times do
      patch "/api/v1/accounts/#{account.id}/bookings/#{booking.id}/reschedule",
            headers: agent.create_new_auth_token,
            params: {
              starts_at: '2026-08-31T06:30:00Z',
              idempotency_key: 'reschedule-once'
            },
            as: :json
    end

    expect(response).to have_http_status(:success)
    expect(booking.reload.starts_at).to eq(Time.zone.parse('2026-08-31T06:30:00Z'))
    expect(booking.calendar_event_payload.dig('mutations', 'reschedule-once')).to include('action' => 'reschedule')
    expect(booking.lead_qualification).to be_call_booked
    expect(Audited::Audit.where(auditable: booking).last.audited_changes).to include('ai_lead_employee_action' => 'booking_reschedule')
    expect(Message.outgoing.where(conversation: conversation).count).to eq(1)
  end

  it 'cancels once for an idempotency key and marks the Lead for Human Operator review' do
    booking = create(
      :booking,
      account: account,
      contact: contact,
      conversation: conversation,
      assignee: agent,
      lead_qualification: contact.lead_qualification
    )

    2.times do
      post "/api/v1/accounts/#{account.id}/bookings/#{booking.id}/cancel",
           headers: agent.create_new_auth_token,
           params: {
             reason: 'Lead asked to pause',
             idempotency_key: 'cancel-once'
           },
           as: :json
    end

    expect(response).to have_http_status(:success)
    expect(booking.reload).to be_canceled
    expect(booking.calendar_event_payload).to include('calendar_state' => 'canceled', 'cancel_reason' => 'Lead asked to pause')
    expect(booking.lead_qualification).to be_human_review
    expect(Audited::Audit.where(auditable: booking).last.audited_changes).to include('ai_lead_employee_action' => 'booking_cancel')
    expect(Message.outgoing.where(conversation: conversation).count).to eq(1)
  end
end
