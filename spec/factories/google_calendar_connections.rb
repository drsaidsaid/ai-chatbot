# frozen_string_literal: true

FactoryBot.define do
  factory :google_calendar_connection, class: 'AiLeadEmployee::GoogleCalendarConnection' do
    account
    provider { 'google_calendar' }
    status { :connected }
    calendar_id { 'primary' }
    access_token { 'google-access-secret' }
    refresh_token { 'google-refresh-secret' }
    token_expires_at { 1.hour.from_now }
    granted_scopes { ['https://www.googleapis.com/auth/calendar'] }
  end
end
