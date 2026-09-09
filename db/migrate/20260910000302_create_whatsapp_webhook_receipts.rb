class CreateWhatsappWebhookReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_webhook_receipts do |t|
      t.text :raw_body, null: false
      t.string :body_digest, null: false
      t.jsonb :verified_routes, null: false, default: []
      t.datetime :expanded_at
      t.string :error_code
      t.timestamps
    end
    add_index :whatsapp_webhook_receipts, :body_digest, unique: true
    add_index :whatsapp_webhook_receipts, :expanded_at
  end
end
