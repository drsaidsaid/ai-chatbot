# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_lead_employee_evaluation_runs
#
#  id                     :bigint           not null, primary key
#  automated_passed       :boolean          default(FALSE), not null
#  completed_at           :datetime
#  configuration_snapshot :jsonb            not null
#  expected_results       :jsonb            not null
#  grades                 :jsonb            not null
#  knowledge_snapshot     :jsonb            not null
#  messages               :jsonb            not null
#  metrics                :jsonb            not null
#  passed                 :boolean          default(FALSE), not null
#  prompt_version         :string           default("ai-orchestration-v1"), not null
#  provider_snapshot      :jsonb            not null
#  review_status          :integer          default("pending_review"), not null
#  reviewed_at            :datetime
#  reviewer_decision      :jsonb            not null
#  scenario_key           :string           not null
#  scenario_name          :string           not null
#  simulation_identifier  :string           not null
#  status                 :integer          default("completed"), not null
#  steps                  :jsonb            not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  reviewed_by_id         :bigint
#  user_id                :bigint           not null
#
# Indexes
#
#  idx_ai_lead_eval_runs_on_account_passed                   (account_id,passed)
#  idx_ai_lead_eval_runs_on_account_scenario                 (account_id,scenario_key,created_at)
#  index_ai_lead_employee_evaluation_runs_on_account_id      (account_id)
#  index_ai_lead_employee_evaluation_runs_on_reviewed_by_id  (reviewed_by_id)
#  index_ai_lead_employee_evaluation_runs_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class AiLeadEmployee::EvaluationRun < ApplicationRecord
  self.table_name = 'ai_lead_employee_evaluation_runs'

  GRADE_KEYS = %w[
    approved_answer_use
    qualification_question_behavior
    invention_avoidance
    next_step
    lead_quality
    booking_eligibility
    handoff_eligibility
    tone
    safety
  ].freeze
  LEGACY_GRADE_KEYS = %w[answer_correctness qualification_correctness source_quality next_action].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :reviewed_by, class_name: 'User', optional: true

  enum :status, { completed: 0, failed: 1, running: 2, cancelled: 3, stale_configuration: 4, failed_model_call: 5 }
  enum :review_status, { pending_review: 0, reviewed: 1 }

  validates :scenario_key, :scenario_name, :simulation_identifier, :prompt_version, presence: true
  validate :validate_grade_keys

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
  scope :reviewed_passes, -> { reviewed.where(passed: true) }

  def apply_grades!(reviewer:, grades:)
    sanitized = self.class.sanitize_grades(grades)
    reviewer_passed = self.class.grades_passed?(sanitized)
    review_time = Time.current
    update!(
      grades: sanitized,
      review_status: :reviewed,
      reviewed_by: reviewer,
      reviewed_at: review_time,
      passed: automated_passed? && reviewer_passed,
      reviewer_decision: {
        passed: reviewer_passed,
        grades: sanitized,
        reviewed_by_id: reviewer.id,
        reviewed_at: review_time.iso8601
      }
    )
  end

  def serious_issue_count
    metrics.fetch('serious_issue_count', metrics.fetch('serious_safety_failures', 0)).to_i +
      grades.values.count { |grade| ActiveModel::Type::Boolean.new.cast(grade['serious_issue']) }
  end

  def self.sanitize_grades(grade_params)
    params = normalize_grade_aliases(grade_params.to_h)
    GRADE_KEYS.to_h do |key|
      grade = params[key].to_h.with_indifferent_access
      [key, {
        'passed' => ActiveModel::Type::Boolean.new.cast(grade[:passed]),
        'notes' => grade[:notes].to_s,
        'serious_issue' => ActiveModel::Type::Boolean.new.cast(grade[:serious_issue])
      }]
    end
  end

  def self.grades_passed?(grade_params)
    GRADE_KEYS.all? { |key| grade_params.dig(key, 'passed') == true } &&
      grade_params.values.none? { |grade| ActiveModel::Type::Boolean.new.cast(grade['serious_issue']) }
  end

  def self.normalize_grade_aliases(params)
    params = params.with_indifferent_access
    {
      approved_answer_use: params[:approved_answer_use] || params[:answer_correctness],
      qualification_question_behavior: params[:qualification_question_behavior] || params[:qualification_correctness],
      next_step: params[:next_step] || params[:next_action]
    }.compact.each { |target_key, value| params[target_key] ||= value }
    params
  end

  private

  def validate_grade_keys
    return if grades.blank?

    unknown_keys = grades.keys - GRADE_KEYS - LEGACY_GRADE_KEYS
    errors.add(:grades, "contains unsupported keys: #{unknown_keys.join(', ')}") if unknown_keys.present?
  end
end
