# frozen_string_literal: true

class AiLeadEmployee::AiProviderLedgerUsage < AiLeadEmployee::AiProviderLedgerRecord
  self.table_name = 'ai_provider_usages'

  belongs_to :ai_provider_connection,
             class_name: 'AiLeadEmployee::AiProviderLedgerConnection',
             inverse_of: :usages

  scope :for_utc_day, ->(day) { where(period_on: day) }

  validate :account_matches_connection

  private

  def account_matches_connection
    return if account_id.blank? || ai_provider_connection.blank?
    return if account_id == ai_provider_connection.account_id

    errors.add(:account_id, 'must match the AI provider connection Business Account')
  end
end
