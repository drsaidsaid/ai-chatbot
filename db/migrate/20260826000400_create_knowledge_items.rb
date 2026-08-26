# frozen_string_literal: true

class CreateKnowledgeItems < ActiveRecord::Migration[7.1]
  def change
    create_table :knowledge_items do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :title, null: false
      t.text :question, null: false
      t.text :answer, null: false
      t.integer :source_kind, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :approved_at
      t.datetime :rejected_at
      t.datetime :deactivated_at
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :knowledge_items, [:account_id, :status, :source_kind]
  end
end
