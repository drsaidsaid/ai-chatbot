# frozen_string_literal: true

class CreateAiProviderUsages < ActiveRecord::Migration[7.2]
  # rubocop:disable Metrics/MethodLength
  def change
    create_table :ai_provider_usages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_provider_connection, null: false, foreign_key: true
      t.integer :configuration_version, null: false
      t.string :purpose, null: false
      t.date :period_on, null: false
      t.string :status, null: false, default: 'reserved'
      t.integer :requested_output_tokens, null: false
      t.string :provider_request_id
      t.string :model
      t.integer :input_tokens
      t.integer :output_tokens
      t.integer :total_tokens
      t.decimal :cost_usd, precision: 18, scale: 8
      t.boolean :cost_available, null: false, default: false
      t.string :failure_class
      t.datetime :started_at, null: false
      t.datetime :completed_at

      t.timestamps
    end

    add_index :ai_provider_usages, [:account_id, :period_on]
    add_index :ai_provider_usages, [:ai_provider_connection_id, :configuration_version],
              name: 'idx_ai_provider_usages_on_connection_version'
  end
  # rubocop:enable Metrics/MethodLength
end
