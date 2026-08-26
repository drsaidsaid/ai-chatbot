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
end
