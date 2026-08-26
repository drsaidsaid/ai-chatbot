# frozen_string_literal: true

class CreateLeadFollowUps < ActiveRecord::Migration[7.1]
  def change
    create_follow_up_opt_outs_table
    create_follow_ups_table
    add_follow_up_indexes
  end

  private

  def create_follow_up_opt_outs_table
    create_table :lead_follow_up_opt_outs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, foreign_key: true
      t.references :message, foreign_key: true
      t.string :reason, null: false
      t.datetime :opted_out_at, null: false

      t.timestamps
    end
  end

  def create_follow_ups_table # rubocop:disable Metrics/MethodLength
    create_table :lead_follow_ups do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :lead_qualification, null: false, foreign_key: true
      t.references :qualification_question, foreign_key: true
      t.references :message, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :attempt_number, null: false
      t.integer :stage, null: false
      t.text :question_text, null: false
      t.text :content
      t.string :cancellation_reason
      t.string :failure_reason
      t.integer :control_version, null: false
      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.datetime :cancelled_at
      t.datetime :failed_at

      t.timestamps
    end
  end

  def add_follow_up_indexes
    add_index :lead_follow_up_opt_outs, [:account_id, :contact_id], unique: true
    add_index :lead_follow_ups, [:account_id, :conversation_id, :status]
    add_index :lead_follow_ups, [:account_id, :contact_id, :stage, :attempt_number],
              unique: true,
              name: 'idx_lead_follow_ups_on_logical_attempt'
    add_index :lead_follow_ups, [:status, :scheduled_at]
  end
end
