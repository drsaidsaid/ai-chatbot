# frozen_string_literal: true

class CreateMetaWhatsappWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :meta_whatsapp_webhook_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.references :channel_whatsapp, null: false, foreign_key: { to_table: :channel_whatsapp }
      t.string :provider_event_id, null: false
      t.string :event_kind, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :processed_at

      t.timestamps
    end

    add_index :meta_whatsapp_webhook_events, :provider_event_id, unique: true
  end
end
