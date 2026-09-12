# frozen_string_literal: true

class AddFollowUpAttemptLineage < ActiveRecord::Migration[7.2]
  def up
    create_attempt_table
    add_attempt_constraints
    add_artifact_lineage
    backfill_attempt_history
    finalize_attempt_ownership
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Attempt lineage cannot collapse into the old Lead-only key without losing history; see ADR0015'
  end

  private

  def create_attempt_table
    create_table :lead_follow_up_attempts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :offer, foreign_key: { to_table: :ai_lead_employee_offers }
      t.integer :stage, null: false
      t.integer :attempt_number, null: false
      t.bigint :current_follow_up_id
      t.string :admission_state, null: false, default: 'unadmitted'
      t.datetime :admitted_at
      t.timestamps
    end
  end

  def add_attempt_constraints
    add_index :lead_follow_up_attempts, [:account_id, :contact_id, :offer_id, :stage, :attempt_number],
              unique: true, where: 'offer_id IS NOT NULL', name: 'idx_follow_up_attempt_offer_budget'
    add_index :lead_follow_up_attempts, [:account_id, :contact_id, :stage, :attempt_number],
              unique: true, where: 'offer_id IS NULL', name: 'idx_follow_up_attempt_legacy_budget'
    add_check_constraint :lead_follow_up_attempts, "admission_state IN ('unadmitted','admitted','accepted','unknown','failed','blocked')",
                         name: 'follow_up_attempt_admission_state'
    add_check_constraint :lead_follow_up_attempts, 'attempt_number > 0 AND stage IN (0,1)', name: 'follow_up_attempt_positive_budget'
  end

  def add_artifact_lineage
    add_reference :lead_follow_ups, :follow_up_attempt, foreign_key: { to_table: :lead_follow_up_attempts }
    add_column :lead_follow_ups, :qualification_context, :jsonb, null: false, default: {}
    add_column :lead_follow_ups, :question_key, :string
    add_reference :lead_follow_ups, :replaces_follow_up, foreign_key: { to_table: :lead_follow_ups }, index: { unique: true }
    add_reference :lead_follow_ups, :replaced_by_follow_up, foreign_key: { to_table: :lead_follow_ups }
    add_column :lead_follow_ups, :superseded_at, :datetime
    add_column :lead_follow_ups, :replacement_reason, :string
  end

  def backfill_attempt_history
    # Only the recorded Qualification supplies Offer scope. Historical pending
    # rows have no frozen decision/selection proof and gain no replacement right.
    execute <<~SQL.squish
      INSERT INTO lead_follow_up_attempts
        (account_id, contact_id, offer_id, stage, attempt_number, current_follow_up_id,
         admission_state, admitted_at, created_at, updated_at)
      SELECT f.account_id, f.contact_id, q.offer_id, f.stage, f.attempt_number, f.id,
        CASE WHEN d.state = 'accepted' OR f.status = 1 OR NULLIF(m.source_id, '') IS NOT NULL THEN 'accepted'
             WHEN d.state = 'unknown' THEN 'unknown'
             WHEN d.state = 'dispatching' THEN 'admitted'
             WHEN d.state = 'failed' OR f.status = 3 THEN 'failed'
             ELSE 'blocked' END,
        COALESCE(d.dispatch_started_at, d.accepted_at, f.sent_at), f.created_at, f.updated_at
      FROM lead_follow_ups f
      JOIN lead_qualifications q ON q.id = f.lead_qualification_id
      LEFT JOIN messages m ON m.id = f.message_id
      LEFT JOIN whatsapp_outbound_deliveries d ON d.message_id = f.message_id;

      UPDATE lead_follow_ups f SET follow_up_attempt_id = a.id
      FROM lead_follow_up_attempts a WHERE a.current_follow_up_id = f.id;
    SQL
  end

  def finalize_attempt_ownership
    change_column_null :lead_follow_ups, :follow_up_attempt_id, false
    add_foreign_key :lead_follow_up_attempts, :lead_follow_ups, column: :current_follow_up_id
    add_index :lead_follow_ups, :follow_up_attempt_id, unique: true, where: 'superseded_at IS NULL',
                                                       name: 'idx_follow_up_attempt_current_artifact'
    remove_index :lead_follow_ups, name: 'idx_lead_follow_ups_on_logical_attempt'
  end
end
