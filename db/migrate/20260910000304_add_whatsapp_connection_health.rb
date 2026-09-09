class AddWhatsappConnectionHealth < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_whatsapp, :webhook_registered_at, :datetime
    add_column :channel_whatsapp, :webhook_error_code, :string
    add_index :whatsapp_webhook_receipts, :verified_routes, using: :gin
  end
end
