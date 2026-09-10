class CreateWhatsappOutboundDeliveries < ActiveRecord::Migration[7.2]
  def change
    create_table :whatsapp_outbound_deliveries do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.integer :observed_control_version, null: false
      t.string :state, null: false, default: 'pending'
      t.string :owner_token
      t.datetime :lease_expires_at
      t.integer :attempts, null: false, default: 0
      t.datetime :dispatch_started_at
      t.datetime :accepted_at
      t.string :provider_message_id
      t.string :failure_code
      t.timestamps
    end
    add_index :whatsapp_outbound_deliveries, [:state, :lease_expires_at]
  end
end
