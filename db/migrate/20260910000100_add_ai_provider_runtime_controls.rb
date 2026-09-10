# frozen_string_literal: true

class AddAiProviderRuntimeControls < ActiveRecord::Migration[7.2]
  def change
    change_table :ai_provider_connections, bulk: true do |t|
      t.integer :reply_token_limit, null: false, default: 512
      t.integer :daily_request_limit, null: false, default: 0
      t.integer :configuration_version, null: false, default: 1
      t.integer :last_health_configuration_version
    end
  end
end
