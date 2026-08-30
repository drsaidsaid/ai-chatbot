# frozen_string_literal: true

class CreateAiOrchestrationIntentsAndOutboxEvents < ActiveRecord::Migration[7.1]
  def change
    create_ai_orchestration_intents
    add_ai_orchestration_intent_indexes
    create_outbox_events
    add_outbox_event_indexes
  end

  private

  def create_ai_orchestration_intents
    create_table :ai_orchestration_intents do |t|
      add_ai_orchestration_intent_references(t)
      t.integer :observed_control_version, null: false
      t.integer :state, null: false, default: 0
      t.string :idempotency_key, null: false
      t.string :selected_provider
      t.string :model
      t.string :failure_class
      t.string :blocked_reason
      t.jsonb :source_references, null: false, default: []
      t.jsonb :decision, null: false, default: {}
      t.integer :attempts, null: false, default: 0
      t.datetime :completed_at
      t.datetime :blocked_at

      t.timestamps
    end
  end

  def add_ai_orchestration_intent_references(table)
    table.references :account, null: false, foreign_key: true
    table.references :conversation, null: false, foreign_key: true
    table.references :triggering_message, null: false, foreign_key: { to_table: :messages }
    table.references :review_request, foreign_key: { to_table: :human_review_requests }
    table.references :outbound_message, foreign_key: { to_table: :messages }
  end

  def add_ai_orchestration_intent_indexes
    add_index :ai_orchestration_intents, [:account_id, :idempotency_key], unique: true
    add_index :ai_orchestration_intents, [:account_id, :conversation_id, :state]
    add_index :ai_orchestration_intents,
              [:account_id, :conversation_id, :triggering_message_id, :observed_control_version],
              unique: true,
              name: 'idx_ai_orchestration_intents_on_logical_trigger'
  end

  def create_outbox_events
    create_table :outbox_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :aggregate, polymorphic: true, null: false
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :idempotency_key, null: false
      t.integer :state, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.datetime :delivered_at
      t.datetime :failed_at
      t.string :failure_class

      t.timestamps
    end
  end

  def add_outbox_event_indexes
    add_index :outbox_events, [:account_id, :idempotency_key], unique: true
    add_index :outbox_events, [:account_id, :event_type, :state]
  end
end
