# frozen_string_literal: true

class CreateBusinessSetupSources < ActiveRecord::Migration[7.2]
  def change
    create_sources_table
    add_scope_constraints
  end

  private

  def create_sources_table
    create_table :business_setup_sources do |t|
      t.references :account, null: false, foreign_key: true
      t.references :offer, null: false, foreign_key: { to_table: :ai_lead_employee_offers }
      t.references :knowledge_document, foreign_key: true
      t.references :published_by, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :source_type, null: false
      t.text :body, null: false
      t.jsonb :proposal, null: false, default: {}
      t.jsonb :history, null: false, default: []
      t.integer :status, null: false, default: 0
      t.integer :version, null: false, default: 1
      t.integer :published_offer_version
      t.datetime :published_at
      t.timestamps
    end

    add_index :business_setup_sources, [:account_id, :offer_id, :updated_at]
  end

  def add_scope_constraints
    add_foreign_key :business_setup_sources, :ai_lead_employee_offers,
                    column: [:offer_id, :account_id], primary_key: [:id, :account_id],
                    name: 'fk_business_setup_sources_offer_scope'
    add_foreign_key :business_setup_sources, :knowledge_documents,
                    column: [:knowledge_document_id, :account_id], primary_key: [:id, :account_id],
                    name: 'fk_business_setup_sources_document_scope'
  end
end
