class CreateWhatsappWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_webhook_events do |t|
      t.references :receipt, null: false, foreign_key: { to_table: :whatsapp_webhook_receipts }
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :channel, null: false, foreign_key: { to_table: :channel_whatsapp }
      t.string :event_key, null: false
      t.string :kind, null: false
      t.string :provider_message_id
      t.datetime :provider_created_at
      t.jsonb :payload, null: false
      t.integer :state, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.datetime :processed_at
      t.datetime :next_attempt_at
      t.string :error_code
      t.timestamps
    end
    add_event_indexes
    add_column :messages, :provider_created_at, :datetime
  end

  private

  def add_event_indexes
    add_index :whatsapp_webhook_events, [:channel_id, :event_key], unique: true
    add_index :whatsapp_webhook_events, [:state, :next_attempt_at]
    add_index :whatsapp_webhook_events, [:inbox_id, :provider_message_id]
  end
end
