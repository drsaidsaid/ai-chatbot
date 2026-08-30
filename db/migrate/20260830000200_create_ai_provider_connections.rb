# frozen_string_literal: true

class CreateAiProviderConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_provider_connections do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: 'openrouter'
      t.string :model, null: false
      t.text :api_key
      t.integer :status, null: false, default: 0
      t.datetime :disabled_at
      t.datetime :last_health_checked_at
      t.string :last_health_status
      t.string :last_health_failure_class
      t.jsonb :last_health_response, null: false, default: {}

      t.timestamps
    end
  end
end
