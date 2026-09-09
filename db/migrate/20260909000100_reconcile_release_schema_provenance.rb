# frozen_string_literal: true

# The audited RC contained these definitions only in schema.rb. Preserve data
# in schema-loaded installations while making checkpoint upgrades converge.
# See ADR 0008; these reserved tables do not implement per-Offer qualification.
class ReconcileReleaseSchemaProvenance < ActiveRecord::Migration[7.2]
  def up
    create_offers unless table_exists?(:ai_lead_employee_offers)
    create_hard_rules unless table_exists?(:qualification_hard_rules)
    create_score_ranges unless table_exists?(:qualification_score_ranges)
    add_column :qualification_questions, :required, :boolean, default: true, null: false unless column_exists?(:qualification_questions, :required)
    unless column_exists?(:qualification_questions, :validation_key)
      add_column :qualification_questions, :validation_key, :string, default: 'plain_text', null: false
    end
    change_column_default :human_review_requests, :reason, 0
    change_column_default :ai_lead_employee_evaluation_runs, :prompt_version, 'ai-orchestration-v1'
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Reconciled objects may predate this migration and contain operator data; restore a verified backup.'
  end

  private

  def create_offers
    create_table :ai_lead_employee_offers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :price, default: '', null: false
      t.text :best_for, default: '', null: false
      t.string :primary_action, default: '', null: false
      t.boolean :enabled, default: true, null: false
      t.integer :position, default: 0, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
      t.index [:account_id, :enabled, :position], name: 'idx_ai_lead_offers_on_account_enabled_position'
      t.index [:account_id, :name], unique: true
    end
  end

  def create_hard_rules
    create_table :qualification_hard_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.text :description, default: '', null: false
      t.boolean :enabled, default: true, null: false
      t.integer :position, default: 0, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
      t.index [:account_id, :enabled, :position], name: 'idx_qualification_hard_rules_on_account_enabled_position'
      t.index [:account_id, :key], unique: true
    end
  end

  def create_score_ranges
    create_table :qualification_score_ranges do |t|
      t.references :account, null: false, foreign_key: true
      t.string :quality, null: false
      t.integer :min_score, null: false
      t.integer :max_score, null: false
      t.string :label, null: false
      t.text :meaning, default: '', null: false
      t.text :examples, default: '', null: false
      t.integer :position, default: 0, null: false
      t.boolean :enabled, default: true, null: false
      t.timestamps
      t.index [:account_id, :position], name: 'idx_qualification_score_ranges_on_account_position'
    end
  end
end
