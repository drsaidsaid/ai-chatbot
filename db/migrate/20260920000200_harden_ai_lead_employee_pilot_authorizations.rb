# frozen_string_literal: true

class HardenAiLeadEmployeePilotAuthorizations < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_lead_employee_pilot_authorizations, :external_owner_approval_reference, :string
    add_check_constraint :ai_lead_employee_pilot_authorizations,
                         'external_owner_approval_reference IS NOT NULL AND char_length(btrim(external_owner_approval_reference)) > 0',
                         name: 'pilot_authorizations_owner_approval_reference'
    create_table :ai_lead_employee_pilot_authorization_events do |t|
      t.references :pilot_authorization, null: false, foreign_key: { to_table: :ai_lead_employee_pilot_authorizations }
      t.references :platform_app, null: false, foreign_key: true
      t.string :action, null: false
      t.string :reason
      t.timestamps
    end
    add_check_constraint :ai_lead_employee_pilot_authorization_events, "action IN ('activated', 'paused', 'revoked')",
                         name: 'pilot_authorization_events_action'
  end
end
