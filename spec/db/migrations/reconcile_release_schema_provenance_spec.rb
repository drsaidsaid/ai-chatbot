# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20260909000100_reconcile_release_schema_provenance')

RSpec.describe ReconcileReleaseSchemaProvenance do
  it 'preserves schema-loaded operator data and customized question values on reapplication' do
    account = create(:account)
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL.squish
      INSERT INTO ai_lead_employee_offers (account_id, name, price, created_at, updated_at)
      VALUES (#{account.id}, 'Existing offer', 'TZS 500', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      INSERT INTO qualification_hard_rules (account_id, key, label, created_at, updated_at)
      VALUES (#{account.id}, 'existing_rule', 'Existing rule', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
      INSERT INTO qualification_score_ranges (account_id, quality, min_score, max_score, label, created_at, updated_at)
      VALUES (#{account.id}, 'qualified', 50, 79, 'Existing range', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    question = QualificationQuestion.create!(account: account, signal: :business_type, prompt: 'Your business?',
                                             required: false, validation_key: 'existing_validation')

    2.times { described_class.new.migrate(:up) }

    expect(connection.select_value("SELECT price FROM ai_lead_employee_offers WHERE account_id = #{account.id}")).to eq('TZS 500')
    expect(connection.select_value("SELECT label FROM qualification_hard_rules WHERE account_id = #{account.id}")).to eq('Existing rule')
    expect(connection.select_value("SELECT max_score FROM qualification_score_ranges WHERE account_id = #{account.id}")).to eq(79)
    expect(question.reload.attributes.slice('required', 'validation_key')).to eq('required' => false, 'validation_key' => 'existing_validation')
  end

  it 'refuses a rollback that could destroy pre-existing operator data' do
    expect { described_class.new.migrate(:down) }.to raise_error(ActiveRecord::IrreversibleMigration, /verified backup/)
  end
end
