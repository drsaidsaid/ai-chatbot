# frozen_string_literal: true

abort 'Disposable R10 browser database only' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'ale_release_r10_browser'

load Rails.root.join('script/release/seed_synthetic.rb')

admin = User.find_by!(email: 'release-operator@example.test')
password = ENV.fetch('RELEASE_ADMIN_PASSWORD')
checked_at = Time.current.change(sec: 0)

failed_account = Account.find_by!(name: 'R01 Synthetic Business')
failed_account.update!(name: 'R10 Provider Failure', reporting_timezone: 'Africa/Nairobi')
member = User.new(name: 'R10 Team Member', email: 'r10-member@example.test', password: password)
member.skip_confirmation!
member.save!
AccountUser.create!(account: failed_account, user: member, role: :agent)
failed_connection = AiLeadEmployee::AiProviderConnection.create!(
  account: failed_account,
  api_key: 'synthetic-r10-never-send',
  model: 'openai/gpt-4.1-mini',
  reply_token_limit: 512,
  daily_request_limit: 25,
  configuration_version: 2,
  last_health_checked_at: checked_at,
  last_health_status: 'failed',
  last_health_failure_class: 'insufficient_credits',
  last_health_configuration_version: 2,
  last_health_response: {
    status: 'failed',
    failure_class: 'insufficient_credits',
    configuration_version: 2,
    reply_token_limit: 512,
    model: 'openai/gpt-4.1-mini'
  }
)
AiLeadEmployee::AiProviderUsage.create!(
  account: failed_account,
  ai_provider_connection: failed_connection,
  configuration_version: 2,
  purpose: 'health_check',
  period_on: Time.current.utc.to_date,
  status: 'failed',
  requested_output_tokens: 512,
  failure_class: 'insufficient_credits',
  started_at: checked_at,
  completed_at: checked_at
)

exhausted_account = Account.create!(name: 'R10 Allowance Exhausted', locale: 'en', reporting_timezone: 'Africa/Nairobi')
AccountUser.create!(account: exhausted_account, user: admin, role: :administrator)
exhausted_connection = AiLeadEmployee::AiProviderConnection.create!(
  account: exhausted_account,
  api_key: 'synthetic-r10-never-send',
  model: 'openai/gpt-4.1-mini',
  reply_token_limit: 512,
  daily_request_limit: 3,
  last_health_checked_at: checked_at,
  last_health_status: 'healthy',
  last_health_configuration_version: 1,
  last_health_response: {
    status: 'healthy', configuration_version: 1, reply_token_limit: 512, model: 'openai/gpt-4.1-mini'
  }
)
3.times do |index|
  AiLeadEmployee::AiProviderUsage.create!(
    account: exhausted_account,
    ai_provider_connection: exhausted_connection,
    configuration_version: 1,
    purpose: index.zero? ? 'health_check' : 'answer',
    period_on: Time.current.utc.to_date,
    status: 'completed',
    requested_output_tokens: 512,
    started_at: checked_at + index.seconds,
    completed_at: checked_at + index.seconds
  )
end

puts(
  {
    failed_account_id: failed_account.id,
    exhausted_account_id: exhausted_account.id,
    admin_email: admin.email,
    member_email: member.email
  }.to_json
)
puts 'Synthetic provider credentials are local placeholders; external network access remains blocked.'
