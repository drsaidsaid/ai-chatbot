# frozen_string_literal: true

class AddNameQualificationQuestion < ActiveRecord::Migration[7.1]
  NAME_SIGNAL = 7

  def up
    shift_existing_questions!
    insert_name_questions!
  end

  def down
    execute <<~SQL.squish
      UPDATE qualification_questions AS question
      SET position = GREATEST(position - 1, 0), updated_at = CURRENT_TIMESTAMP
      WHERE signal != #{NAME_SIGNAL}
        AND EXISTS (
          SELECT 1
          FROM qualification_questions AS name_question
          WHERE name_question.account_id = question.account_id
            AND name_question.signal = #{NAME_SIGNAL}
        )
    SQL

    execute "DELETE FROM qualification_questions WHERE signal = #{NAME_SIGNAL}"
  end

  private

  def shift_existing_questions!
    execute <<~SQL.squish
      UPDATE qualification_questions AS question
      SET position = position + 1, updated_at = CURRENT_TIMESTAMP
      WHERE NOT EXISTS (
        SELECT 1
        FROM qualification_questions AS name_question
        WHERE name_question.account_id = question.account_id
          AND name_question.signal = #{NAME_SIGNAL}
      )
    SQL
  end

  def insert_name_questions!
    execute <<~SQL.squish
      INSERT INTO qualification_questions
        (account_id, signal, prompt, position, enabled, required, validation_key, metadata, created_at, updated_at)
      SELECT DISTINCT account_id, #{NAME_SIGNAL}, 'What is your name?', 0, TRUE, TRUE, 'plain_text', '{}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM qualification_questions
      WHERE NOT EXISTS (
        SELECT 1
        FROM qualification_questions AS name_question
        WHERE name_question.account_id = qualification_questions.account_id
          AND name_question.signal = #{NAME_SIGNAL}
      )
    SQL
  end
end
