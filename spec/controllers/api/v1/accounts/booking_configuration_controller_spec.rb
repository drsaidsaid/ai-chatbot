# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Booking Configuration API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  it 'lets an admin connect a calendar and configure booking rules' do
    patch "/api/v1/accounts/#{account.id}/booking_configuration",
          headers: admin.create_new_auth_token,
          params: {
            provider: 'google_calendar',
            calendar_id: 'sales@example.test',
            connected: true,
            timezone: 'Africa/Dar_es_Salaam',
            working_days: [1, 2, 3, 4, 5],
            allowed_hours: { start: '10:00', end: '16:00' },
            duration_minutes: 45,
            buffer_before_minutes: 10,
            buffer_after_minutes: 15,
            minimum_notice_minutes: 180
          },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'provider' => 'google_calendar',
      'calendar_id' => 'sales@example.test',
      'connected' => true,
      'timezone' => 'Africa/Dar_es_Salaam',
      'duration_minutes' => 45,
      'minimum_notice_minutes' => 180
    )
  end

  it 'prevents a Human Operator without admin access from changing booking configuration' do
    patch "/api/v1/accounts/#{account.id}/booking_configuration",
          headers: agent.create_new_auth_token,
          params: { connected: true, calendar_id: 'sales@example.test' },
          as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(AiLeadEmployee::BookingConfiguration.for(account)['connected']).to be(false)
  end
end
