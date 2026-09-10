# frozen_string_literal: true

class AiLeadEmployee::AiProviderLedgerConnection < AiLeadEmployee::AiProviderLedgerRecord
  self.table_name = 'ai_provider_connections'

  has_many :usages,
           class_name: 'AiLeadEmployee::AiProviderLedgerUsage',
           foreign_key: :ai_provider_connection_id,
           inverse_of: :ai_provider_connection,
           dependent: :restrict_with_exception

  def configured?
    status.zero? && self[:api_key].present?
  end
end
