# frozen_string_literal: true

class AiLeadEmployee::AiProvider::HealthCheck
  Result = Struct.new(:status, :failure_class, :checked_at, keyword_init: true)

  def initialize(connection:)
    @connection = connection
  end

  def perform
    checked_at = Time.current
    AiLeadEmployee::AiProvider::ClientFactory.for(account: connection.account).complete(
      messages: [{ role: 'user', content: 'Reply with ok.' }],
      max_tokens: 8,
      temperature: 0
    )
    update_connection!(checked_at: checked_at, status: 'healthy', failure_class: nil)
  rescue AiLeadEmployee::AiProvider::ProviderFailure => e
    update_connection!(checked_at: checked_at || Time.current, status: 'failed', failure_class: e.failure_class)
  end

  private

  attr_reader :connection

  def update_connection!(checked_at:, status:, failure_class:)
    connection.update!(
      last_health_checked_at: checked_at,
      last_health_status: status,
      last_health_failure_class: failure_class,
      last_health_response: {
        status: status,
        failure_class: failure_class
      }.compact
    )

    Result.new(status: status, failure_class: failure_class, checked_at: checked_at)
  end
end
