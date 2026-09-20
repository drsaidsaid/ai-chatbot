# frozen_string_literal: true

class CreateAiLeadEmployeePilotAuthorizations < ActiveRecord::Migration[7.2]
  def change # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    add_column :platform_apps, :pilot_operations_enabled, :boolean, null: false, default: false

    create_table :ai_lead_employee_pilot_authorizations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :ai_provider_connection, null: false, foreign_key: true
      t.references :authorized_by_platform_app, null: false, foreign_key: { to_table: :platform_apps },
                                                index: { name: 'idx_pilot_authorizations_on_platform_app' }
      t.string :recipient, null: false
      t.integer :control_version, null: false
      t.integer :provider_configuration_version, null: false
      t.string :status, null: false, default: 'active'
      t.integer :max_attempts, null: false
      t.decimal :max_spend_usd, precision: 18, scale: 8, null: false
      t.decimal :provider_limit_usd, precision: 18, scale: 8, null: false
      t.datetime :provider_limit_verified_at, null: false
      t.jsonb :provider_limit_evidence, null: false, default: {}
      t.datetime :starts_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :paused_at
      t.string :pause_reason
      t.timestamps
    end

    add_index :ai_lead_employee_pilot_authorizations,
              [:account_id, :conversation_id, :status],
              name: 'idx_pilot_authorizations_on_scope_status'
    add_index :ai_lead_employee_pilot_authorizations,
              [:account_id, :conversation_id], unique: true, where: "status = 'active'",
                                               name: 'idx_one_active_pilot_authorization_per_conversation'
    add_check_constraint :ai_lead_employee_pilot_authorizations,
                         "status IN ('active', 'paused', 'revoked')", name: 'pilot_authorizations_status'
    add_check_constraint :ai_lead_employee_pilot_authorizations, 'max_attempts > 0',
                         name: 'pilot_authorizations_positive_attempts'
    add_check_constraint :ai_lead_employee_pilot_authorizations, 'max_spend_usd > 0',
                         name: 'pilot_authorizations_positive_spend'
    add_check_constraint :ai_lead_employee_pilot_authorizations,
                         'provider_limit_usd > 0 AND provider_limit_usd <= max_spend_usd',
                         name: 'pilot_authorizations_bounded_provider_limit'
    add_check_constraint :ai_lead_employee_pilot_authorizations, 'expires_at > starts_at',
                         name: 'pilot_authorizations_forward_window'

    add_reference :ai_orchestration_intents, :pilot_authorization,
                  foreign_key: { to_table: :ai_lead_employee_pilot_authorizations },
                  index: { name: 'idx_ai_intents_on_pilot_authorization' }
    add_reference :ai_provider_usages, :pilot_authorization,
                  foreign_key: { to_table: :ai_lead_employee_pilot_authorizations },
                  index: { name: 'idx_ai_provider_usages_on_pilot_authorization' }
    add_reference(
      :ai_provider_usages,
      :ai_orchestration_intent,
      foreign_key: true,
      index: { name: 'idx_ai_provider_usages_on_orchestration_intent' }
    )
  end
end
