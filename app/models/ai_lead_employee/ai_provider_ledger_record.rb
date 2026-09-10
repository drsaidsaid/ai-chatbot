# frozen_string_literal: true

class AiLeadEmployee::AiProviderLedgerRecord < ApplicationRecord
  self.abstract_class = true

  LEDGER_POOL_SIZE = ENV.fetch('AI_PROVIDER_LEDGER_DB_POOL', 2).to_i
  LEDGER_CHECKOUT_TIMEOUT = ENV.fetch('AI_PROVIDER_LEDGER_DB_CHECKOUT_TIMEOUT', 1).to_f

  establish_connection(
    ActiveRecord::Base.connection_db_config.configuration_hash.merge(
      pool: LEDGER_POOL_SIZE,
      checkout_timeout: LEDGER_CHECKOUT_TIMEOUT
    )
  )
end
