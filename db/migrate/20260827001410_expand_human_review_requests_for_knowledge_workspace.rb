# frozen_string_literal: true

class ExpandHumanReviewRequestsForKnowledgeWorkspace < ActiveRecord::Migration[7.1]
  def change
    add_reference :human_review_requests, :assigned_user, foreign_key: { to_table: :users }
    add_column :human_review_requests, :operator_answer, :text
    add_column :human_review_requests, :resolution_kind, :string
    add_column :human_review_requests, :rejected_at, :datetime
  end
end
