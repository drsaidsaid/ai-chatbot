# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
class CreateAiLeadEmployeeEvaluationGate < ActiveRecord::Migration[7.1]
  PROMPT_VERSION = 'ai-orchestration-v1'

  def change
    create_evaluation_runs_table
    create_launch_gates_table
  end

  private

  def create_evaluation_runs_table
    return reconcile_existing_evaluation_runs_table if table_exists?(:ai_lead_employee_evaluation_runs)

    create_table :ai_lead_employee_evaluation_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :scenario_key, null: false
      t.string :scenario_name, null: false
      t.integer :status, default: 0, null: false
      t.boolean :automated_passed, default: false, null: false
      t.boolean :passed, default: false, null: false
      t.integer :review_status, default: 0, null: false
      t.jsonb :messages, default: [], null: false
      t.jsonb :steps, default: [], null: false
      t.jsonb :grades, default: {}, null: false
      t.jsonb :metrics, default: {}, null: false
      t.jsonb :expected_results, default: {}, null: false
      t.jsonb :configuration_snapshot, default: {}, null: false
      t.jsonb :knowledge_snapshot, default: {}, null: false
      t.jsonb :provider_snapshot, default: {}, null: false
      t.string :prompt_version, null: false
      t.jsonb :reviewer_decision, default: {}, null: false
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at
      t.string :simulation_identifier, null: false
      t.datetime :completed_at
      t.timestamps
    end

    add_index :ai_lead_employee_evaluation_runs, [:account_id, :scenario_key, :created_at], name: 'idx_ai_lead_eval_runs_on_account_scenario'
    add_index :ai_lead_employee_evaluation_runs, [:account_id, :passed], name: 'idx_ai_lead_eval_runs_on_account_passed'
  end

  def create_launch_gates_table
    return if table_exists?(:ai_lead_employee_launch_gates)

    create_table :ai_lead_employee_launch_gates do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.boolean :team_roleplay_completed, default: false, null: false
      t.integer :pilot_conversations_reviewed_count, default: 0, null: false
      t.text :approval_notes
      t.jsonb :report, default: {}, null: false
      t.references :approved_by, foreign_key: { to_table: :users }
      t.datetime :approved_at
      t.timestamps
    end
  end

  def reconcile_existing_evaluation_runs_table
    add_column :ai_lead_employee_evaluation_runs, :provider_snapshot, :jsonb, default: {}, null: false unless column_exists?(
      :ai_lead_employee_evaluation_runs, :provider_snapshot
    )
    add_column :ai_lead_employee_evaluation_runs, :prompt_version, :string unless column_exists?(:ai_lead_employee_evaluation_runs, :prompt_version)
    add_column :ai_lead_employee_evaluation_runs, :reviewer_decision, :jsonb, default: {}, null: false unless column_exists?(
      :ai_lead_employee_evaluation_runs, :reviewer_decision
    )
    add_reference :ai_lead_employee_evaluation_runs, :reviewed_by, foreign_key: { to_table: :users } unless column_exists?(
      :ai_lead_employee_evaluation_runs, :reviewed_by_id
    )
    add_column :ai_lead_employee_evaluation_runs, :reviewed_at, :datetime unless column_exists?(:ai_lead_employee_evaluation_runs, :reviewed_at)

    change_column_default :ai_lead_employee_evaluation_runs, :prompt_version, from: nil, to: PROMPT_VERSION
    reversible do |dir|
      dir.up do
        update <<~SQL.squish
          UPDATE ai_lead_employee_evaluation_runs
          SET prompt_version = '#{PROMPT_VERSION}'
          WHERE prompt_version IS NULL OR prompt_version = ''
        SQL
      end
    end
    change_column_null :ai_lead_employee_evaluation_runs, :prompt_version, false

    unless index_exists?(
      :ai_lead_employee_evaluation_runs, [:account_id, :scenario_key, :created_at], name: 'idx_ai_lead_eval_runs_on_account_scenario'
    )
      add_index :ai_lead_employee_evaluation_runs, [:account_id, :scenario_key, :created_at],
                name: 'idx_ai_lead_eval_runs_on_account_scenario'
    end
    add_index :ai_lead_employee_evaluation_runs, [:account_id, :passed], name: 'idx_ai_lead_eval_runs_on_account_passed' unless index_exists?(
      :ai_lead_employee_evaluation_runs, [:account_id, :passed], name: 'idx_ai_lead_eval_runs_on_account_passed'
    )
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
