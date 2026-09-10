# frozen_string_literal: true

class AiLeadEmployee::AiProvider::ClientFactory
  def self.for(account:)
    new(account: account).client
  end

  def initialize(account:)
    @account = account
  end

  def client
    connection = account.ai_provider_connection
    raise AiLeadEmployee::AiProvider::DisabledFailure, 'AI provider connection is not configured' if connection.blank?
    raise AiLeadEmployee::AiProvider::DisabledFailure, 'AI provider connection is disabled' unless connection.configured?

    adapter = case connection.provider
              when 'openrouter'
                AiLeadEmployee::AiProvider::OpenRouterAdapter.new(connection: connection)
              else
                raise AiLeadEmployee::AiProvider::DisabledFailure, 'AI provider is not supported'
              end

    AiLeadEmployee::AiProvider::MeteredClient.new(connection: connection, adapter: adapter)
  end

  private

  attr_reader :account
end
