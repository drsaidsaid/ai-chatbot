# frozen_string_literal: true

class AddConfigurableQualificationAssessment < ActiveRecord::Migration[7.2]
  def up
    add_column :lead_qualifications, :assessment, :jsonb, null: false, default: {}
    add_column :lead_qualification_decisions, :assessment, :jsonb, null: false, default: {}

    execute <<~SQL.squish
      UPDATE ai_lead_employee_offers
      SET configuration = configuration || jsonb_build_object(
        'qualification_mode',
        CASE
          WHEN jsonb_array_length(COALESCE(configuration->'questions', '[]'::jsonb)) > 0
            OR jsonb_array_length(COALESCE(configuration->'rules', '[]'::jsonb)) > 0
            OR COALESCE(configuration->'score_weights', '{}'::jsonb) <> '{}'::jsonb
          THEN 'enabled'
          ELSE 'not_configured'
        END,
        'next_step', COALESCE(configuration->'next_step', '{"kind":"answer_only"}'::jsonb)
      )
      WHERE NOT configuration ? 'qualification_mode'
    SQL
  end

  def down
    remove_column :lead_qualification_decisions, :assessment
    remove_column :lead_qualifications, :assessment
  end
end
