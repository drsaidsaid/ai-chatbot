# frozen_string_literal: true

class CreateHumanReviewRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :human_review_requests do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :lead_message, null: false, foreign_key: { to_table: :messages }
      t.references :human_answer_message, foreign_key: { to_table: :messages }
      t.references :knowledge_item, foreign_key: true
      t.integer :reason, null: false
      t.integer :status, null: false, default: 0
      t.string :proposed_source_kind
      t.text :question, null: false
      t.jsonb :alert_recipients, null: false, default: []
      t.jsonb :alert_deliveries, null: false, default: []
      t.datetime :resolved_at

      t.timestamps
    end

    add_index :human_review_requests,
              [:account_id, :conversation_id, :lead_message_id, :reason],
              unique: true,
              name: 'index_human_review_requests_on_deduplication_key'
    add_index :human_review_requests, [:account_id, :status, :created_at]
  end
end
