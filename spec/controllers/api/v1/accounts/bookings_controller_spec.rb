# frozen_string_literal: true

require 'rails_helper'

# The eager records are authorization/provider prerequisites exercised indirectly by request examples.
# rubocop:disable RSpec/LetSetup

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
                          assignee: agent, offer: offer)
  end
  let!(:calendar_connection) { create(:google_calendar_connection, account: account, calendar_id: 'sales') }
  let!(:qualification) do
    create(:lead_qualification, account: account, contact: conversation.contact, offer: offer, quality: :qualified,
                                configuration_version: 1,
                                assessment: { 'fit' => { 'status' => 'met' }, 'readiness' => { 'status' => 'met' },
                                              'action_eligibility' => { 'status' => 'met' } },
                                evidence_snapshot: { 'problem' => { 'value' => 'need more leads' } })
  end
  let!(:proposal_message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: agent,
                     message_type: :outgoing, content: 'Would Monday at 9 work?',
                     additional_attributes: {
                       ai_lead_employee: { booking_proposal: {
                         idempotency_key: 'initial-proposal', starts_at: '2026-08-31T06:00:00Z',
                         ends_at: '2026-08-31T06:30:00Z', offer_id: offer.id,
                         offer_configuration_version: offer.configuration_version
                       } }
                     })
  end
  let!(:agreement_message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Yes, Monday at 9')
  end
  let!(:agreement_evidence) do
    create(:qualification_evidence, account: account, contact: contact, conversation: conversation, offer: offer,
                                    message: agreement_message, field_key: 'sales_call_agreement',
                                    value: { 'value' => 'yes', 'typed_value' => true, 'polarity' => 'positive',
                                             'agreed_starts_at' => '2026-08-31T06:00:00Z',
                                             'proposal_message_id' => proposal_message.id,
                                             'offer_configuration_version' => offer.configuration_version })
  end

  before do
    stub_request(:post, 'https://www.googleapis.com/calendar/v3/freeBusy')
      .to_return(status: 200, body: { calendars: { 'sales' => { busy: [] } } }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events})
      .to_return(status: 200, body: { id: 'google-created-event' }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:patch, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events/.+})
      .to_return(status: 200, body: { id: 'google-updated-event' }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:delete, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events/.+}).to_return(status: 204, body: '')
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
             agreed_starts_at: '2026-08-31T06:00:00Z',
             agreement_message_id: agreement_message.id,
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

  it 'proposes one live provider-backed time with current Offer revision evidence' do
    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      post "/api/v1/accounts/#{account.id}/bookings/propose",
           headers: agent.create_new_auth_token,
           params: {
             conversation_id: conversation.id,
             starts_at: '2026-08-31T06:00:00Z',
             idempotency_key: 'proposal-request-key'
           },
           as: :json

      expect(response).to have_http_status(:created)
      proposal = conversation.messages.outgoing.find(response.parsed_body.fetch('message_id'))
      expect(proposal.content).to include('Monday, August 31 at 9:00 AM EAT')
      expect(proposal.additional_attributes.dig('ai_lead_employee', 'booking_proposal')).to include(
        'starts_at' => '2026-08-31T06:00:00Z',
        'offer_id' => offer.id,
        'offer_configuration_version' => offer.configuration_version
      )
    end
  end

  it 'returns an honest unknown result and explicitly reconciles the deterministic provider create' do
    stub_request(:post, %r{https://www.googleapis.com/calendar/v3/calendars/.+/events}).to_return(
      { status: 503, body: { error: { message: 'unavailable' } }.to_json,
        headers: { 'Content-Type' => 'application/json' } },
      { status: 200, body: { id: 'google-reconciled-event' }.to_json,
        headers: { 'Content-Type' => 'application/json' } }
    )

    travel_to Time.zone.parse('2026-08-31T04:30:00Z') do
      post "/api/v1/accounts/#{account.id}/bookings",
           headers: agent.create_new_auth_token,
           params: {
             conversation_id: conversation.id,
             starts_at: '2026-08-31T06:00:00Z',
             agreed_starts_at: '2026-08-31T06:00:00Z',
             agreement_message_id: agreement_message.id,
             idempotency_key: 'unknown-request-key'
           },
           as: :json

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body).to include('provider_state' => 'unknown', 'code' => 'provider_result_unknown')
      booking = Booking.find(response.parsed_body.fetch('id'))
      expect(booking).to have_attributes(status: 'provider_unknown', confirmation_message_id: nil)

      post "/api/v1/accounts/#{account.id}/bookings/#{booking.id}/reconcile",
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('status' => 'confirmed', 'provider_state' => 'confirmed')
      expect(booking.reload.provider_event_id).to eq('google-reconciled-event')
    end
  end

  it 'does not synthesize eligibility when no selected Offer exists' do
    conversation.update!(offer: nil)
    qualification.destroy!
    expect(AiLeadEmployee::QualificationService).not_to receive(:new)

    post "/api/v1/accounts/#{account.id}/bookings",
         headers: agent.create_new_auth_token,
         params: {
           conversation_id: conversation.id,
           starts_at: '2026-08-31T06:00:00Z',
           agreed_starts_at: '2026-08-31T06:00:00Z',
           agreement_message_id: agreement_message.id,
           idempotency_key: 'no-offer-request'
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['code']).to eq('booking_offer_required')
    expect(LeadQualification.where(account: account, contact: contact)).to be_empty
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
      'whatsapp_state' => 'awaiting',
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
    ).tap { |booking| booking.conversation.update!(assignee: booking.assignee) }
    create(
      :booking,
      account: account,
      assignee: agent,
      starts_at: Time.zone.parse('2040-01-01T11:30:00Z'),
      ends_at: Time.zone.parse('2040-01-01T12:00:00Z')
    ).tap { |booking| booking.conversation.update!(assignee: booking.assignee) }

    get "/api/v1/accounts/#{account.id}/bookings",
        headers: agent.create_new_auth_token,
        params: { from: '2026-08-24T00:00:00Z' },
        as: :json

    expect(response.parsed_body['bookings'].pluck('id')).to eq([in_range.id])
  end

  it 'serializes an uncertain mutation as provider unknown instead of confirmed' do
    reschedule_booking = create(
      :booking,
      account: account,
      assignee: agent,
      status: :confirmed,
      provider_state: 'unknown',
      provider_operation: { 'action' => 'reschedule', 'state' => 'unknown' },
      starts_at: Time.zone.parse('2026-08-27T11:30:00Z'),
      ends_at: Time.zone.parse('2026-08-27T12:00:00Z')
    )
    reschedule_booking.conversation.update!(assignee: agent)
    cancel_booking = create(
      :booking,
      account: account,
      assignee: agent,
      status: :confirmed,
      provider_state: 'unknown',
      provider_operation: { 'action' => 'cancel', 'state' => 'unknown' },
      starts_at: Time.zone.parse('2026-08-27T13:30:00Z'),
      ends_at: Time.zone.parse('2026-08-27T14:00:00Z')
    )
    cancel_booking.conversation.update!(assignee: agent)

    get "/api/v1/accounts/#{account.id}/bookings",
        headers: agent.create_new_auth_token,
        params: { from: '2026-08-24T00:00:00Z', status: 'provider_unknown' },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['bookings'].pluck('id')).to contain_exactly(reschedule_booking.id, cancel_booking.id)
    expect(response.parsed_body['bookings']).to all(include(
                                                      'status' => 'provider_unknown', 'provider_state' => 'unknown', 'calendar_state' => 'unknown'
                                                    ))
  end

  it 'limits Team Members to bookings on their assigned conversations' do
    assigned_booking = create(:booking, account: account, assignee: agent)
    assigned_booking.conversation.update!(assignee: agent)
    create(
      :booking,
      account: account,
      assignee: create(:user, account: account, role: :agent),
      starts_at: assigned_booking.starts_at + 1.hour,
      ends_at: assigned_booking.ends_at + 1.hour
    ).tap { |booking| booking.conversation.update!(assignee: booking.assignee) }

    get "/api/v1/accounts/#{account.id}/bookings",
        headers: agent.create_new_auth_token,
        params: { from: assigned_booking.starts_at.beginning_of_week.iso8601 },
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
      starts_at: Time.zone.parse('2026-09-21T06:00:00Z'),
      ends_at: Time.zone.parse('2026-09-21T06:30:00Z')
    )

    2.times do
      patch "/api/v1/accounts/#{account.id}/bookings/#{booking.id}/reschedule",
            headers: agent.create_new_auth_token,
            params: {
              starts_at: '2026-09-21T06:30:00Z',
              idempotency_key: 'reschedule-once'
            },
            as: :json
    end

    expect(response).to have_http_status(:success)
    expect(booking.reload.starts_at).to eq(Time.zone.parse('2026-09-21T06:30:00Z'))
    expect(booking.calendar_event_payload.dig('mutations', 'reschedule-once')).to include('action' => 'reschedule')
    expect(booking.lead_qualification).to be_call_booked
    expect(Audited::Audit.where(auditable: booking).last.audited_changes).to include('ai_lead_employee_action' => 'booking_reschedule')
    expect(Message.outgoing.where(conversation: conversation).count).to eq(2)
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
    expect(Message.outgoing.where(conversation: conversation).count).to eq(2)
  end
end
# rubocop:enable RSpec/LetSetup
