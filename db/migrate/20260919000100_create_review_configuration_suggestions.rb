# frozen_string_literal: true

class CreateReviewConfigurationSuggestions < ActiveRecord::Migration[7.1]
  def change
    create_table :review_configuration_suggestions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :human_review_request, null: false, foreign_key: true, index: { unique: true }
      t.references :conversation, null: false, foreign_key: true
      t.references :offer, foreign_key: { to_table: :ai_lead_employee_offers }
      t.references :source_message, null: false, foreign_key: { to_table: :messages }
      t.references :proposed_by_user, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by_user, foreign_key: { to_table: :users }
      t.integer :category, null: false
      t.integer :status, null: false, default: 0
      t.text :suggestion, null: false
      t.text :evidence, null: false
      t.text :decision_note
      t.datetime :reviewed_at
      t.timestamps
    end

    add_index :review_configuration_suggestions, [:account_id, :status, :created_at],
              name: 'idx_review_configuration_suggestions_queue'
  end
end
