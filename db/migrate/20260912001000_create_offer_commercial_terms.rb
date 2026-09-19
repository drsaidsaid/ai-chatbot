# frozen_string_literal: true

class CreateOfferCommercialTerms < ActiveRecord::Migration[7.2]
  def change # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    add_index :ai_lead_employee_offers, [:id, :account_id], unique: true, name: 'idx_ai_offer_account_scope'
    add_index :knowledge_documents, [:id, :account_id], unique: true, name: 'idx_knowledge_document_account_scope'

    create_table :offer_commercial_terms do |t|
      t.references :account, null: false, foreign_key: true
      t.references :offer, null: false, foreign_key: { to_table: :ai_lead_employee_offers }, index: { unique: true }
      t.jsonb :draft, null: false, default: {}
      t.integer :draft_version, null: false, default: 0
      t.timestamps
    end
    add_index :offer_commercial_terms, [:id, :offer_id, :account_id],
              unique: true, name: 'idx_offer_commercial_term_scope'
    add_foreign_key :offer_commercial_terms, :ai_lead_employee_offers,
                    column: [:offer_id, :account_id], primary_key: [:id, :account_id],
                    name: 'fk_commercial_terms_offer_scope'

    create_table :offer_commercial_term_revisions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :offer, null: false, foreign_key: { to_table: :ai_lead_employee_offers }
      t.references :commercial_term, null: false, foreign_key: { to_table: :offer_commercial_terms }
      t.references :published_by, foreign_key: { to_table: :users }
      t.integer :revision, null: false
      t.jsonb :snapshot, null: false
      t.string :content_digest, null: false
      t.datetime :published_at, null: false
      t.timestamps
      t.index [:offer_id, :revision], unique: true, name: 'idx_offer_commercial_revisions_unique'
      t.index [:account_id, :published_at], name: 'idx_offer_commercial_revisions_account_time'
    end
    add_foreign_key :offer_commercial_term_revisions, :ai_lead_employee_offers,
                    column: [:offer_id, :account_id], primary_key: [:id, :account_id],
                    name: 'fk_commercial_revisions_offer_scope'
    add_foreign_key :offer_commercial_term_revisions, :offer_commercial_terms,
                    column: [:commercial_term_id, :offer_id, :account_id], primary_key: [:id, :offer_id, :account_id],
                    name: 'fk_commercial_revisions_term_scope'

    add_column :offer_commercial_terms, :published_revision_id, :bigint
    add_index :offer_commercial_terms, :published_revision_id, unique: true
    add_index :offer_commercial_term_revisions, [:id, :commercial_term_id, :offer_id, :account_id],
              unique: true, name: 'idx_offer_commercial_revision_scope'
    add_foreign_key :offer_commercial_terms, :offer_commercial_term_revisions,
                    column: [:published_revision_id, :id, :offer_id, :account_id],
                    primary_key: [:id, :commercial_term_id, :offer_id, :account_id],
                    name: 'fk_offer_commercial_terms_published_scope'

    create_table :offer_commercial_proposals do |t|
      t.references :account, null: false, foreign_key: true
      t.references :offer, null: false, foreign_key: { to_table: :ai_lead_employee_offers }
      t.references :knowledge_document, null: false, foreign_key: true
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.string :source_digest, null: false
      t.jsonb :proposed_terms, null: false
      t.jsonb :conflict_details, null: false, default: {}
      t.datetime :reviewed_at
      t.timestamps
      t.index [:knowledge_document_id, :offer_id, :source_digest],
              unique: true, name: 'idx_offer_commercial_proposals_document_offer'
      t.index [:account_id, :status], name: 'idx_offer_commercial_proposals_account_status'
    end
    add_foreign_key :offer_commercial_proposals, :ai_lead_employee_offers,
                    column: [:offer_id, :account_id], primary_key: [:id, :account_id],
                    name: 'fk_commercial_proposals_offer_scope'
    add_foreign_key :offer_commercial_proposals, :knowledge_documents,
                    column: [:knowledge_document_id, :account_id], primary_key: [:id, :account_id],
                    name: 'fk_commercial_proposals_document_scope'
  end
end
