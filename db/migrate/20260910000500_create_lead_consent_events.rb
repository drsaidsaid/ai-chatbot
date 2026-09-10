# frozen_string_literal: true

class CreateLeadConsentEvents < ActiveRecord::Migration[7.1]
  def change
    create_consent_events
    add_consent_event_indexes_and_constraints
    add_reference :lead_follow_up_opt_outs, :consent_event, foreign_key: { to_table: :lead_consent_events }
  end

  private

  def create_consent_events
    create_table :lead_consent_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.references :whatsapp_webhook_event, null: false, foreign_key: { to_table: :whatsapp_webhook_events }
      t.string :event_kind, null: false
      t.string :purpose, null: false
      t.string :reason, null: false
      t.text :evidence_text, null: false
      t.string :recognizer_version, null: false
      t.string :actor_type, null: false
      t.bigint :actor_id, null: false
      t.datetime :occurred_at, null: false
      t.datetime :recorded_at, null: false

      t.timestamps
    end
  end

  def add_consent_event_indexes_and_constraints
    add_index :lead_consent_events, [:account_id, :purpose, :message_id],
              unique: true, name: 'idx_lead_consent_events_on_source'
    add_index :lead_consent_events, [:account_id, :contact_id, :purpose, :recorded_at],
              name: 'idx_lead_consent_events_on_history'
    add_check_constraint :lead_consent_events, "event_kind IN ('withdrawn', 'granted')",
                         name: 'lead_consent_events_kind'
    add_check_constraint :lead_consent_events, "purpose = 'automated_contact'",
                         name: 'lead_consent_events_purpose'
  end
end
