# frozen_string_literal: true

class CreateLeadQualificationDecisions < ActiveRecord::Migration[7.1]
  def change
    create_table :lead_qualification_decisions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :lead_qualification, null: false, foreign_key: true
      t.integer :quality, null: false
      t.integer :follow_up_state, null: false
      t.integer :score, null: false
      t.jsonb :reasons, null: false, default: []
      t.jsonb :missing_signals, null: false, default: []
      t.jsonb :evidence_snapshot, null: false, default: {}
      t.integer :configuration_version, null: false
      t.datetime :decided_at, null: false

      t.timestamps
    end

    add_index :lead_qualification_decisions, [:account_id, :contact_id, :decided_at],
              name: 'idx_lead_qualification_decisions_on_lead'
  end
end
