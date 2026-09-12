# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_provider_connections
#
#  id                        :bigint           not null, primary key
#  api_key                   :text
#  disabled_at               :datetime
#  last_health_checked_at    :datetime
#  last_health_failure_class :string
#  last_health_response      :jsonb            not null
#  last_health_status        :string
#  model                     :string           not null
#  provider                  :string           default("openrouter"), not null
#  status                    :integer          default("active"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#
# Indexes
#
#  index_ai_provider_connections_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AiLeadEmployee::AiProviderConnection < ApplicationRecord
  self.table_name = 'ai_provider_connections'

  PROVIDERS = %w[openrouter].freeze
  REPLY_TOKEN_LIMIT_RANGE = 1..4096
  DAILY_REQUEST_LIMIT_RANGE = 0..100_000

  belongs_to :account
  has_many :usages, class_name: 'AiLeadEmployee::AiProviderUsage', dependent: :destroy

  encrypts :api_key if Chatwoot.encryption_configured?

  enum :status, { active: 0, disabled: 1 }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :model, presence: true
  validates :api_key, presence: true, if: :active?
  validates :reply_token_limit, numericality: { only_integer: true, in: REPLY_TOKEN_LIMIT_RANGE }
  validates :daily_request_limit, numericality: { only_integer: true, in: DAILY_REQUEST_LIMIT_RANGE }
  validate :api_key_requires_configured_encryption

  def disable!
    with_lock do
      next if disabled? && api_key.blank?

      update!(
        api_key: nil,
        status: :disabled,
        disabled_at: Time.current,
        configuration_version: configuration_version + 1,
        last_health_checked_at: nil,
        last_health_status: nil,
        last_health_failure_class: nil,
        last_health_configuration_version: nil,
        last_health_response: {}
      )
    end
  end

  def configured?
    active? && api_key.present?
  end

  def redacted_payload
    {
      id: id,
      provider: provider,
      model: model,
      status: status,
      has_credentials: api_key.present?,
      disabled_at: disabled_at,
      configuration_version: configuration_version,
      readiness_status: readiness_status,
      reply_token_limit: reply_token_limit,
      daily_request_limit: daily_request_limit
    }.merge(usage_payload, health_payload)
  end

  # Business Account payload. Provider identity, model routing, credential state,
  # configuration revisions, provider costs and diagnostic failure classes are
  # intentionally reserved for Platform Operators.
  def managed_service_payload
    usage = usage_payload
    {
      managed_service: true,
      service_status: configured? ? 'active' : 'disabled',
      readiness_status: readiness_status,
      last_health_checked_at: last_health_checked_at,
      last_health_checked_at_label: time_label(last_health_checked_at),
      daily_request_limit: daily_request_limit,
      requests_used_today: usage.fetch(:requests_used_today),
      requests_remaining_today: usage.fetch(:requests_remaining_today),
      usage_resets_at: usage.fetch(:usage_resets_at),
      usage_resets_at_label: usage.fetch(:usage_resets_at_label),
      automation_allowed: usage.fetch(:automation_allowed),
      automation_paused_reason: usage.fetch(:automation_paused_reason),
      reporting_timezone: usage.fetch(:reporting_timezone)
    }
  end

  def usage_payload
    usage = usage_summary
    reset_at = Time.current.utc.tomorrow.beginning_of_day
    pause_reason = automation_paused_reason(requests_used: usage.fetch(:requests))
    {
      requests_used_today: usage.fetch(:requests),
      requests_remaining_today: [daily_request_limit - usage.fetch(:requests), 0].max,
      usage_resets_at: reset_at,
      automation_allowed: pause_reason.nil?,
      automation_paused_reason: pause_reason,
      cost_usd_today: usage.fetch(:cost_usd),
      cost_data_complete: usage.fetch(:cost_data_complete),
      reporting_timezone: reporting_time_zone.name,
      usage_resets_at_label: time_label(reset_at)
    }
  end

  def health_payload
    {
      last_health_checked_at: last_health_checked_at,
      last_health_checked_at_label: time_label(last_health_checked_at),
      last_health_status: last_health_status,
      last_health_failure_class: last_health_failure_class,
      last_health_model: last_health_response['model'],
      last_health_reply_token_limit: last_health_response['reply_token_limit'],
      last_health_configuration_version: last_health_response['configuration_version']
    }
  end

  def readiness_status
    return 'disabled' unless configured?
    return 'not_checked' if last_health_status.blank? || last_health_configuration_version != configuration_version

    last_health_status
  end

  def usage_summary(day: Time.current.utc.to_date)
    records = usages.where(account_id: account_id).for_utc_day(day)
    requests = records.count
    cost_data_complete = records.where(cost_available: false).none?
    {
      requests: requests,
      cost_usd: requests.positive? && cost_data_complete ? records.sum(:cost_usd) : nil,
      cost_data_complete: cost_data_complete
    }
  end

  def automation_paused_reason(requests_used: nil)
    return 'provider_disabled' unless configured?

    requests_used ||= usages.for_utc_day(Time.current.utc.to_date).count
    return 'usage_limit_exhausted' if daily_request_limit <= requests_used

    nil
  end

  private

  def reporting_time_zone
    zone_name = account.reporting_timezone.presence
    (ActiveSupport::TimeZone[zone_name] if zone_name) || Time.zone || ActiveSupport::TimeZone['UTC']
  end

  def time_label(time)
    time&.in_time_zone(reporting_time_zone)&.strftime('%Y-%m-%d %H:%M %Z')
  end

  def api_key_requires_configured_encryption
    return if api_key.blank? || Chatwoot.encryption_configured?

    errors.add(:api_key, 'cannot be stored until Active Record encryption is configured')
  end
end
