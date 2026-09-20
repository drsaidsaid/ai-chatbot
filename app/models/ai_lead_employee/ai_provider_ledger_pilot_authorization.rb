# frozen_string_literal: true

class AiLeadEmployee::AiProviderLedgerPilotAuthorization < AiLeadEmployee::AiProviderLedgerRecord
  self.table_name = 'ai_lead_employee_pilot_authorizations'

  has_many :provider_usages, class_name: 'AiLeadEmployee::AiProviderLedgerUsage',
                             foreign_key: :pilot_authorization_id, inverse_of: false,
                             dependent: :restrict_with_exception
end
