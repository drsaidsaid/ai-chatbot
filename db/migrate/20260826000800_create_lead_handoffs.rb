# frozen_string_literal: true

class CreateLeadHandoffs < ActiveRecord::Migration[7.1]
  def change
    create_table :lead_handoffs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :lead_qualification, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :alert_type, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :qualification_snapshot, null: false, default: {}
      t.jsonb :alert_recipients, null: false, default: []
      t.jsonb :alert_deliveries, null: false, default: []
      t.datetime :handed_off_at, null: false

      t.timestamps
    end

    add_index :lead_handoffs, [:account_id, :conversation_id, :lead_qualification_id, :alert_type],
              unique: true,
              name: 'index_lead_handoffs_on_logical_handoff'
  end
end
