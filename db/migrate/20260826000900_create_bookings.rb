# frozen_string_literal: true

class CreateBookings < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'btree_gist'

    create_bookings_table
    add_booking_indexes
  end

  private

  def create_bookings_table # rubocop:disable Metrics/MethodLength
    create_table :bookings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :lead_qualification, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :calendar_id, null: false
      t.string :provider, null: false
      t.string :provider_event_id
      t.string :idempotency_key
      t.integer :status, null: false, default: 0
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :timezone, null: false
      t.jsonb :qualification_evidence_ids, null: false, default: []
      t.jsonb :qualification_snapshot, null: false, default: {}
      t.jsonb :calendar_event_payload, null: false, default: {}
      t.string :confirmation_message_id
      t.datetime :confirmed_at
      t.datetime :calendar_invitation_sent_at
      t.jsonb :preparation_alert_recipients, null: false, default: []
      t.jsonb :preparation_alert_deliveries, null: false, default: []

      t.timestamps
    end
  end

  def add_booking_indexes
    add_index :bookings, [:account_id, :calendar_id, :starts_at],
              unique: true,
              where: 'status = 0',
              name: 'index_bookings_on_active_slot'
    add_index :bookings, [:account_id, :idempotency_key],
              unique: true,
              where: 'idempotency_key IS NOT NULL',
              name: 'index_bookings_on_idempotency_key'
    add_exclusion_constraint :bookings,
                             "account_id WITH =, calendar_id WITH =, tsrange(starts_at, ends_at, '[)') WITH &&",
                             where: 'status = 0',
                             using: :gist,
                             name: 'index_bookings_on_active_slot_overlap'
  end
end
