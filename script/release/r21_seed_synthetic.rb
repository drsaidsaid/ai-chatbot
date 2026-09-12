# frozen_string_literal: true

abort 'Disposable R21 browser database only' unless Rails.env.test? &&
                                                    ActiveRecord::Base.connection_db_config.database == 'ale_release_r21_browser'

load Rails.root.join('script/release/seed_synthetic.rb')

admin = User.find_by!(email: 'release-operator@example.test')
password = ENV.fetch('RELEASE_ADMIN_PASSWORD')
checked_at = Time.current.change(sec: 0)

managed_account = Account.find_by!(name: 'R01 Synthetic Business')
managed_account.update!(name: 'R21 Managed AI', reporting_timezone: 'Africa/Nairobi')
member = User.new(name: 'R21 Team Member', email: 'r21-member@example.test', password: password)
member.skip_confirmation!
member.save!
AccountUser.create!(account: managed_account, user: member, role: :agent)

connection = AiLeadEmployee::AiProviderConnection.create!(
  account: managed_account,
  api_key: 'synthetic-r21-never-send',
  model: 'synthetic/private-route',
  reply_token_limit: 512,
  daily_request_limit: 25,
  last_health_checked_at: checked_at,
  last_health_status: 'healthy',
  last_health_configuration_version: 1,
  last_health_response: {
    status: 'healthy', configuration_version: 1, reply_token_limit: 512, model: 'synthetic/private-route'
  }
)
AiLeadEmployee::AiProviderUsage.create!(
  account: managed_account,
  ai_provider_connection: connection,
  configuration_version: 1,
  purpose: 'answer',
  period_on: Time.current.utc.to_date,
  status: 'completed',
  requested_output_tokens: 512,
  started_at: checked_at,
  completed_at: checked_at
)

other_account = Account.create!(name: 'R21 Unpermitted Account', locale: 'en')
other_connection = AiLeadEmployee::AiProviderConnection.create!(
  account: other_account,
  api_key: 'synthetic-r21-other-never-send',
  model: 'synthetic/other-private-route',
  reply_token_limit: 256,
  daily_request_limit: 10
)
3.times do |index|
  AiLeadEmployee::AiProviderUsage.create!(
    account: other_account,
    ai_provider_connection: other_connection,
    configuration_version: 1,
    purpose: 'answer',
    period_on: Time.current.utc.to_date,
    status: 'completed',
    requested_output_tokens: 256,
    started_at: checked_at + index.seconds,
    completed_at: checked_at + index.seconds,
    cost_available: true,
    cost_usd: 1.25
  )
end

platform_app = PlatformApp.create!(name: 'R21 Synthetic Platform Operator')
PlatformAppPermissible.create!(platform_app: platform_app, permissible: managed_account)

puts(
  {
    managed_account_id: managed_account.id,
    unpermitted_account_id: other_account.id,
    admin_email: admin.email,
    member_email: member.email,
    platform_app_id: platform_app.id
  }.to_json
)
puts 'Synthetic provider values never leave localhost; all external network access remains blocked.'
