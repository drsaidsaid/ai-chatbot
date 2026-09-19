# frozen_string_literal: true

class CreateGoogleCalendarConnectionsAndHardenBookings < ActiveRecord::Migration[7.1]
  def up # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    create_table :google_calendar_connections do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }
      t.string :provider, null: false, default: 'google_calendar'
      t.integer :status, null: false, default: 0
      t.string :calendar_id, null: false, default: 'primary'
      t.string :account_email
      t.text :access_token
      t.text :refresh_token
      t.datetime :token_expires_at
      t.jsonb :granted_scopes, null: false, default: []
      t.string :last_error_code
      t.datetime :last_checked_at
      t.string :oauth_state_digest
      t.datetime :oauth_state_expires_at
      t.bigint :authorization_generation, null: false, default: 0
      t.timestamps
    end

    change_column_null :bookings, :lead_qualification_id, true
    add_reference :bookings, :offer, foreign_key: { to_table: :ai_lead_employee_offers }
    add_reference :bookings, :agreement_evidence, foreign_key: { to_table: :qualification_evidences }
    add_reference :bookings, :agreement_message, foreign_key: { to_table: :messages }
    add_column :bookings, :agreed_at, :datetime
    add_column :bookings, :attendee_email, :string
    add_column :bookings, :provider_state, :string, null: false, default: 'pending'
    add_column :bookings, :provider_error_code, :string
    add_column :bookings, :provider_checked_at, :datetime
    add_column :bookings, :provider_operation, :jsonb, null: false, default: {}
    add_column :bookings, :prerequisite_snapshot, :jsonb, null: false, default: {}
    execute <<~SQL.squish
      UPDATE bookings
      SET provider_state = CASE
        WHEN status = 1 THEN 'canceled'
        WHEN status IN (0, 2) AND provider_event_id IS NOT NULL THEN 'confirmed'
        ELSE 'pending'
      END
    SQL

    remove_index :bookings, name: 'index_bookings_on_active_slot'
    execute 'ALTER TABLE bookings DROP CONSTRAINT index_bookings_on_active_slot_overlap'
    add_index :bookings, [:account_id, :calendar_id, :starts_at], unique: true,
                                                                  where: 'status IN (0, 3, 4)', name: 'index_bookings_on_active_slot'
    add_exclusion_constraint :bookings,
                             "account_id WITH =, calendar_id WITH =, tsrange(starts_at, ends_at, '[)') WITH &&",
                             where: 'status IN (0, 3, 4)', using: :gist,
                             name: 'index_bookings_on_active_slot_overlap'
  end

  def down
    remove_exclusion_constraint :bookings, name: 'index_bookings_on_active_slot_overlap'
    remove_index :bookings, name: 'index_bookings_on_active_slot'
    add_index :bookings, [:account_id, :calendar_id, :starts_at], unique: true,
                                                                  where: 'status = 0', name: 'index_bookings_on_active_slot'
    add_exclusion_constraint :bookings,
                             "account_id WITH =, calendar_id WITH =, tsrange(starts_at, ends_at, '[)') WITH &&",
                             where: 'status = 0', using: :gist,
                             name: 'index_bookings_on_active_slot_overlap'

    remove_columns :bookings, :agreed_at, :attendee_email, :provider_state, :provider_error_code,
                   :provider_checked_at, :provider_operation, :prerequisite_snapshot
    remove_reference :bookings, :agreement_evidence, foreign_key: { to_table: :qualification_evidences }
    remove_reference :bookings, :agreement_message, foreign_key: { to_table: :messages }
    remove_reference :bookings, :offer, foreign_key: { to_table: :ai_lead_employee_offers }
    change_column_null :bookings, :lead_qualification_id, false
    drop_table :google_calendar_connections
  end
end
