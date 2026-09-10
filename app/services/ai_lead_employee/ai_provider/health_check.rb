# frozen_string_literal: true

class AiLeadEmployee::AiProvider::HealthCheck
  Result = Struct.new(:status, :failure_class, :checked_at, keyword_init: true)

  def initialize(connection:)
    @connection = connection
  end

  def perform
    checked_at = Time.current
    provider = {}
    snapshot_provider!(provider)
    response = provider.fetch(:client).complete(
      messages: [{ role: 'user', content: 'Reply with ok.' }],
      max_tokens: provider.fetch(:reply_token_limit),
      temperature: 0,
      purpose: 'health_check'
    )
    update_connection!(checked_at: checked_at, configuration_version: provider[:configuration_version],
                       status: 'healthy', failure_class: nil, model: response.model)
  rescue AiLeadEmployee::AiProvider::ProviderFailure => e
    update_connection!(checked_at: checked_at || Time.current, configuration_version: provider&.dig(:configuration_version),
                       status: 'failed', failure_class: e.failure_class, model: connection.model)
  end

  private

  attr_reader :connection

  def snapshot_provider!(provider)
    connection.with_lock do
      provider[:configuration_version] = connection.configuration_version
      provider[:reply_token_limit] = connection.reply_token_limit
      provider[:client] = AiLeadEmployee::AiProvider::ClientFactory.for(account: connection.account)
    end
  end

  def update_connection!(checked_at:, configuration_version:, status:, failure_class:, model:)
    connection.with_lock do
      return Result.new(status: 'stale', checked_at: checked_at) if connection.configuration_version != configuration_version

      connection.update!(
        last_health_checked_at: checked_at,
        last_health_status: status,
        last_health_failure_class: failure_class,
        last_health_configuration_version: configuration_version,
        last_health_response: {
          status: status,
          failure_class: failure_class,
          configuration_version: configuration_version,
          reply_token_limit: connection.reply_token_limit,
          model: model
        }.compact
      )
    end

    Result.new(status: status, failure_class: failure_class, checked_at: checked_at)
  end
end
