# frozen_string_literal: true

class HardenAiSubscriptionOperations < ActiveRecord::Migration[7.1]
  def change
    rename_column :ai_subscriptions, :exhaustion_alerted_at, :action_required_alerted_at

    create_table :ai_account_cost_allocations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :recorded_by_platform_app, null: false, foreign_key: { to_table: :platform_apps }
      t.string :category, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.string :currency, null: false
      t.date :period_started_on, null: false
      t.date :period_ended_on, null: false
      t.timestamps
    end
    add_index :ai_account_cost_allocations, %i[account_id category currency period_started_on period_ended_on],
              unique: true, name: 'idx_ai_cost_allocations_unique_period'
    add_check_constraint :ai_account_cost_allocations,
                         "category IN ('hosting', 'payment_processing', 'support')", name: 'ai_cost_allocations_category'
    add_check_constraint :ai_account_cost_allocations, 'amount >= 0', name: 'ai_cost_allocations_nonnegative_amount'
    add_check_constraint :ai_account_cost_allocations, 'period_ended_on >= period_started_on', name: 'ai_cost_allocations_period'
  end
end
