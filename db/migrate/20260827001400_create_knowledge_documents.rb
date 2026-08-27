# frozen_string_literal: true

class CreateKnowledgeDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :knowledge_documents do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :last_editor, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body, null: false, default: ''
      t.integer :status, null: false, default: 0
      t.boolean :used_by_ai_employee, null: false, default: true
      t.boolean :general_question_access, null: false, default: true
      t.jsonb :offer_ids, null: false, default: []
      t.jsonb :sensitive_topics, null: false, default: []
      t.jsonb :import_metadata, null: false, default: {}
      t.jsonb :revisions, null: false, default: []
      t.datetime :published_at
      t.datetime :archived_at

      t.timestamps
    end

    add_index :knowledge_documents, [:account_id, :status, :updated_at]
  end
end
