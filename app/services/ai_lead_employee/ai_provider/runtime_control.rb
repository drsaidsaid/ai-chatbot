# frozen_string_literal: true

class AiLeadEmployee::AiProvider::RuntimeControl
  def self.current_configuration?(account:, configuration_version:)
    connection = AiLeadEmployee::AiProviderConnection.find_by(account_id: account.id)
    return false unless connection

    connection.with_lock do
      connection.configured? && connection.configuration_version == configuration_version
    end
  end

  def self.failure_code(account:, configuration_version: nil, usage_period_on: nil)
    connection = AiLeadEmployee::AiProviderConnection.find_by(account_id: account.id)
    return 'provider_disabled' unless connection&.configured?

    connection.with_lock do
      next 'provider_disabled' unless connection.configured?

      authority_failure = provider_authority_failure(connection, configuration_version, usage_period_on)
      next authority_failure if authority_failure

      used = connection.usages.where(account_id: connection.account_id).for_utc_day(Time.current.utc.to_date).count
      'usage_limit_exhausted' if connection.daily_request_limit <= used
    end
  end

  def self.stop_pending_automation!(account:, reason:)
    account.conversations.find_each do |conversation|
      conversation.with_lock do
        Conversations::ControlService.invalidate_pending_ai!(conversation: conversation, reason: reason)
      end
    end
  end

  def self.provider_authority_failure(connection, configuration_version, usage_period_on)
    return 'provider_configuration_changed' if configuration_version && connection.configuration_version != configuration_version.to_i
    return 'provider_usage_period_expired' if usage_period_on && usage_period_on.to_s != Time.current.utc.to_date.iso8601

    nil
  end
  private_class_method :provider_authority_failure
end
