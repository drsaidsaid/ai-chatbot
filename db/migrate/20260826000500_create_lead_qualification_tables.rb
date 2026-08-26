# frozen_string_literal: true

class CreateLeadQualificationTables < ActiveRecord::Migration[7.1]
  def change
    create_table :qualification_questions do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :signal, null: false
      t.text :prompt, null: false
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :qualification_questions, [:account_id, :signal], unique: true
    add_index :qualification_questions, [:account_id, :enabled, :position]

    create_table :qualification_budget_ranges do |t|
      t.references :account, null: false, foreign_key: true
      t.string :label, null: false
      t.integer :min_cents
      t.integer :max_cents
      t.integer :position, null: false, default: 0
      t.boolean :enabled, null: false, default: true

      t.timestamps
    end

    add_index :qualification_budget_ranges, [:account_id, :enabled, :position]

    create_table :qualification_evidences do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, foreign_key: true
      t.references :message, foreign_key: true
      t.references :user, foreign_key: true
      t.references :superseded_by, foreign_key: { to_table: :qualification_evidences }
      t.integer :signal, null: false
      t.jsonb :value, null: false, default: {}
      t.integer :source, null: false
      t.datetime :observed_at, null: false
      t.datetime :superseded_at

      t.timestamps
    end

    add_index :qualification_evidences, [:account_id, :contact_id, :signal, :superseded_at],
              name: 'idx_qualification_evidence_current_lookup'

    create_table :lead_qualifications do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.integer :quality, null: false, default: 0
      t.integer :follow_up_state, null: false, default: 0
      t.integer :score, null: false, default: 0
      t.jsonb :reasons, null: false, default: []
      t.jsonb :missing_signals, null: false, default: []
      t.jsonb :evidence_snapshot, null: false, default: {}
      t.integer :configuration_version, null: false, default: 1
      t.datetime :last_evaluated_at, null: false

      t.timestamps
    end

    add_index :lead_qualifications, [:account_id, :contact_id], unique: true
    add_index :lead_qualifications, [:account_id, :quality]
  end
end
