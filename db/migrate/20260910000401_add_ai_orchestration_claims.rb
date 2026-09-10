class AddAiOrchestrationClaims < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_orchestration_intents, :owner_token, :string
    add_column :ai_orchestration_intents, :lease_expires_at, :datetime
    add_index :ai_orchestration_intents, [:state, :lease_expires_at]
  end
end
