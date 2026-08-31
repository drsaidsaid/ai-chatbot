# frozen_string_literal: true

class Api::V1::Accounts::EvaluationSandboxesController < Api::V1::Accounts::BaseController
  RUN_PAYLOAD_FIELDS = [
    :id,
    :scenario_key,
    :scenario_name,
    :status,
    :automated_passed,
    :passed,
    :review_status,
    :messages,
    :steps,
    :grades,
    :metrics,
    :expected_results,
    :configuration_snapshot,
    :knowledge_snapshot,
    :provider_snapshot,
    :prompt_version,
    :reviewer_decision,
    :reviewed_by_id,
    :reviewed_at,
    :simulation_identifier,
    :completed_at,
    :created_at,
    :updated_at,
    :user_id
  ].freeze

  before_action :check_admin_authorization?

  def show
    render json: sandbox_payload
  end

  def scenarios
    render json: AiLeadEmployee::Evaluation::ScenarioCatalog.all
  end

  def runs
    render json: run_history
  end

  def create_run
    result = AiLeadEmployee::Evaluation::SandboxRunner.new(
      account: current_account,
      user: Current.user,
      scenario_key: params.require(:scenario_key)
    ).perform

    render json: run_payload(result.run), status: :created
  end

  def grade_run
    run = evaluation_runs.find(params[:run_id])
    run.apply_grades!(reviewer: Current.user, grades: grade_params)

    render json: run_payload(run)
  end

  def launch_gate
    render json: launch_gate_status
  end

  def update_launch_gate
    render json: launch_gate_evaluator.update!(launch_gate_params.to_h)
  end

  def approve_launch
    render json: launch_gate_evaluator.approve!(user: Current.user, notes: params[:approval_notes])
  rescue AiLeadEmployee::Evaluation::LaunchGateEvaluator::ApprovalBlocked => e
    render json: { error: e.message, launch_gate: launch_gate_status }, status: :unprocessable_entity
  end

  private

  def sandbox_payload
    {
      scenarios: AiLeadEmployee::Evaluation::ScenarioCatalog.all,
      runs: run_history,
      launch_gate: launch_gate_status
    }
  end

  def run_history
    evaluation_runs.latest_first.limit(100).map { |run| run_payload(run) }
  end

  def evaluation_runs
    AiLeadEmployee::EvaluationRun.where(account: current_account)
  end

  def run_payload(run)
    run.as_json(only: RUN_PAYLOAD_FIELDS).merge(
      'tester' => user_name(run.user),
      'reviewer' => user_name(run.reviewed_by),
      'total_checks' => total_checks(run),
      'passed_checks' => passed_checks(run)
    )
  end

  def user_name(user)
    user&.available_name || user&.name || user&.email
  end

  def total_checks(run)
    run.steps.sum { |step| step.fetch('checks', []).size }
  end

  def passed_checks(run)
    run.steps.sum { |step| step.fetch('checks', []).count { |check| check['passed'] } }
  end

  def launch_gate_status
    launch_gate_evaluator.status
  end

  def launch_gate_evaluator
    @launch_gate_evaluator ||= AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: current_account)
  end

  def grade_params
    params.fetch(:grades, {}).permit(
      answer_correctness: [:passed, :notes, :serious_issue],
      qualification_correctness: [:passed, :notes, :serious_issue],
      tone: [:passed, :notes, :serious_issue],
      safety: [:passed, :notes, :serious_issue],
      source_quality: [:passed, :notes, :serious_issue],
      next_action: [:passed, :notes, :serious_issue]
    )
  end

  def launch_gate_params
    params.permit(:team_roleplay_completed, :pilot_conversations_reviewed_count, :approval_notes)
  end
end
