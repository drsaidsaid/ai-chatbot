# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20260911001700_add_follow_up_attempt_lineage')

RSpec.describe AddFollowUpAttemptLineage do
  # Execute the real migration against isolated historical tables in the same
  # dedicated database. No Rails model reconstructs historical context for us.
  around do |example|
    database = ActiveRecord::Base.connection
    database.transaction(requires_new: true) do
      database.execute('CREATE SCHEMA r09_historical_followups')
      database.execute('SET LOCAL search_path TO r09_historical_followups')
      example.run
      raise ActiveRecord::Rollback
    end
  end

  let(:database) { ActiveRecord::Base.connection }

  before do
    database.execute <<~SQL.squish
      CREATE TABLE accounts (id bigint PRIMARY KEY);
      CREATE TABLE contacts (id bigint PRIMARY KEY);
      CREATE TABLE ai_lead_employee_offers (id bigint PRIMARY KEY);
      CREATE TABLE lead_qualifications (id bigint PRIMARY KEY, offer_id bigint);
      CREATE TABLE messages (id bigint PRIMARY KEY, source_id varchar);
      CREATE TABLE whatsapp_outbound_deliveries (id bigint PRIMARY KEY, message_id bigint, state varchar,
                                                dispatch_started_at timestamp, accepted_at timestamp);
      CREATE TABLE lead_follow_ups (id bigint PRIMARY KEY, account_id bigint, contact_id bigint, conversation_id bigint,
        lead_qualification_id bigint, message_id bigint, stage integer, attempt_number integer,
        status integer, cancellation_reason varchar, content text, sent_at timestamp, created_at timestamp, updated_at timestamp);
      CREATE UNIQUE INDEX idx_lead_follow_ups_on_logical_attempt ON lead_follow_ups (account_id, contact_id, stage, attempt_number);
      INSERT INTO accounts VALUES (1);
      INSERT INTO ai_lead_employee_offers VALUES (77);
    SQL
  end

  it 'retains source identities, derives only recorded Offer scope, and grants no entitlement from ambiguous history' do
    cases = [
      [nil, 0, nil, nil, 'blocked'], ['pending', 0, nil, nil, 'blocked'], ['claimed', 0, nil, nil, 'blocked'],
      ['dispatching', 0, nil, '2026-09-01 10:00:00', 'admitted'], ['accepted', 1, 'wamid.ACCEPTED', '2026-09-01 10:00:00', 'accepted'],
      ['unknown', 0, nil, '2026-09-01 10:00:00', 'unknown'], ['failed', 3, nil, nil, 'failed'],
      ['canceled', 2, nil, nil, 'blocked'], ['pending', 0, '', nil, 'blocked'], [nil, 1, nil, nil, 'accepted']
    ]
    cases.each_with_index do |(state, status, source_id, admitted_at, _expected), index|
      id = index + 1
      offer = index.even? ? '77' : 'NULL'
      database.execute <<~SQL.squish
        INSERT INTO contacts VALUES (#{id});
        INSERT INTO lead_qualifications VALUES (#{id}, #{offer});
        INSERT INTO messages VALUES (#{id}, #{database.quote(source_id)});
        INSERT INTO whatsapp_outbound_deliveries VALUES (#{id}, #{id}, #{database.quote(state)}, #{database.quote(admitted_at)}, NULL);
        INSERT INTO lead_follow_ups VALUES (#{id}, 1, #{id}, #{100 + id}, #{id}, #{id}, 0, 1, #{status},
          'offer_configuration_changed', 'Historical content #{id}', NULL, NOW(), NOW());
      SQL
    end
    described_class.suppress_messages { described_class.new.up }

    rows = database.select_all(
      'SELECT f.*, a.offer_id, a.admission_state, a.admitted_at FROM lead_follow_ups f ' \
      'JOIN lead_follow_up_attempts a ON a.id=f.follow_up_attempt_id ORDER BY f.id'
    ).to_a
    expect(rows.length).to eq(cases.length)
    rows.each_with_index do |row, index|
      expect(row).to include('id' => index + 1, 'message_id' => index + 1, 'conversation_id' => 101 + index,
                             'content' => "Historical content #{index + 1}", 'offer_id' => index.even? ? 77 : nil,
                             'admission_state' => cases[index].last, 'qualification_context' => '{}')
      expect(row['question_key']).to be_nil
    end
    expect(database.indexes(:lead_follow_ups).map(&:name)).not_to include('idx_lead_follow_ups_on_logical_attempt')
    expect(database.indexes(:lead_follow_ups).find { |index| index.name == 'idx_follow_up_attempt_current_artifact' }.unique).to be(true)
    expect { described_class.new.down }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
