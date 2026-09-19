class CreateOutboxEffectReceipts < ActiveRecord::Migration[7.1]
  def change
    create_table :outbox_effect_receipts do |t|
      t.references :outbox_event, null: false, foreign_key: { on_delete: :cascade }
      t.string :consumer, null: false
      t.timestamps
    end

    add_index :outbox_effect_receipts, [:outbox_event_id, :consumer],
              unique: true, name: 'index_outbox_effect_receipts_on_event_and_consumer'
  end
end
