# frozen_string_literal: true

class AiLeadEmployee::AiProviderLedgerUsage < AiLeadEmployee::AiProviderLedgerRecord
  self.table_name = 'ai_provider_usages'

  belongs_to :ai_provider_connection,
             class_name: 'AiLeadEmployee::AiProviderLedgerConnection',
             inverse_of: :usages

  scope :for_utc_day, ->(day) { where(period_on: day) }
end
