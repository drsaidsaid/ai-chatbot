# frozen_string_literal: true

class AiLeadEmployee::PilotAuthorizationEvent < ApplicationRecord
  self.table_name = 'ai_lead_employee_pilot_authorization_events'
  belongs_to :pilot_authorization, class_name: 'AiLeadEmployee::PilotAuthorization'
  belongs_to :platform_app
  validates :action, inclusion: { in: %w[activated paused revoked] }
end
