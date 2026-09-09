# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/migrate/20260831000200_add_name_qualification_question')

RSpec.describe AddNameQualificationQuestion do
  it 'adds one name question per configured account using only the predecessor schema' do
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL.squish
      CREATE TEMPORARY TABLE qualification_questions (
        account_id bigint NOT NULL, signal integer NOT NULL, prompt text NOT NULL,
        position integer DEFAULT 0, enabled boolean DEFAULT true, metadata jsonb DEFAULT '{}',
        created_at timestamp NOT NULL, updated_at timestamp NOT NULL
      ) ON COMMIT DROP
    SQL
    connection.execute <<~SQL.squish
      INSERT INTO qualification_questions (account_id, signal, prompt, position, created_at, updated_at)
      VALUES (101, 0, 'Business?', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (101, 1, 'Problem?', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
             (202, 0, 'Business?', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    2.times { described_class.new.migrate(:up) }

    expect(connection.select_rows('SELECT account_id, signal, position FROM qualification_questions ORDER BY account_id, position'))
      .to eq([[101, 7, 0], [101, 0, 1], [101, 1, 2], [202, 7, 0], [202, 0, 1]])
  end
end
