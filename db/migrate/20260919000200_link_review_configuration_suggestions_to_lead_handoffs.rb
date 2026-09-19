# frozen_string_literal: true

class LinkReviewConfigurationSuggestionsToLeadHandoffs < ActiveRecord::Migration[7.1]
  def change
    change_column_null :review_configuration_suggestions, :human_review_request_id, true
    change_column_null :review_configuration_suggestions, :source_message_id, true
    add_reference :review_configuration_suggestions, :lead_handoff, foreign_key: true, index: { unique: true }
    add_check_constraint :review_configuration_suggestions,
                         '(human_review_request_id IS NOT NULL) <> (lead_handoff_id IS NOT NULL)',
                         name: 'review_configuration_suggestions_one_source'
  end
end
