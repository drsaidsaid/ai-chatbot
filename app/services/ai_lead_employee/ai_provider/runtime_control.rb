# frozen_string_literal: true

class AiLeadEmployee::AiProvider::RuntimeControl
  def self.current_configuration?(account:, configuration_version:)
    connection = AiLeadEmployee::AiProviderConnection.find_by(account_id: account.id)
    return false unless connection

    connection.with_lock do
      connection.configured? && connection.configuration_version == configuration_version
    end
  end

  def self.failure_code(account:)
    connection = AiLeadEmployee::AiProviderConnection.find_by(account_id: account.id)
    return 'provider_disabled' unless connection&.configured?

    connection.with_lock do
      next 'provider_disabled' unless connection.configured?

      used = connection.usages.for_utc_day(Time.current.utc.to_date).count
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
end
