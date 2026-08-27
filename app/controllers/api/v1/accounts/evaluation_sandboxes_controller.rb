# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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
    run = current_account.ai_lead_employee_evaluation_runs.find(params[:run_id])
    run.apply_grades!(reviewer: Current.user, grades: grade_params)

    render json: run_payload(run)
  end

  def propose_knowledge
    run = current_account.ai_lead_employee_evaluation_runs.find(params[:run_id])
    item = current_account.knowledge_items.create!(
      title: correction_params[:title].presence || "Correction for #{run.scenario_name}",
      question: correction_params.require(:question),
      answer: correction_params.require(:answer),
      source_kind: correction_params[:source_kind].presence || :faq,
      status: :draft,
      metadata: {
        proposed_from: 'evaluation_run',
        evaluation_run_id: run.id,
        scenario_key: run.scenario_key,
        step_index: correction_params[:step_index],
        proposed_by_id: Current.user.id,
        approval_required: true
      }.compact
    )

    render json: {
      knowledge_item: item.as_json(only: [:id, :title, :question, :answer, :source_kind, :status, :metadata]),
      run: run_payload(run)
    }, status: :created
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
      launch_gate: launch_gate_status,
      filter_options: filter_options
    }
  end

  def run_history
    filtered_runs.latest_first.limit(100).map { |run| run_payload(run) }
  end

  def run_payload(run)
    run.as_json(only: RUN_PAYLOAD_FIELDS).merge(
      'tester' => run.user&.available_name || run.user&.name || run.user&.email,
      'result' => result_for(run),
      'configuration_version' => run.configuration_snapshot['qualification_config_version'],
      'knowledge_version' => run.knowledge_snapshot['version'],
      'model_identifier' => run.metrics['model_identifier'] || 'deterministic-v1-sandbox',
      'total_checks' => run.steps.sum { |step| step.fetch('checks', []).size },
      'passed_checks' => run.steps.sum { |step| step.fetch('checks', []).count { |check| check['passed'] } }
    )
  end

  def filtered_runs
    current_account.ai_lead_employee_evaluation_runs.then do |scope|
      scope = scope.where(scenario_key: params[:scenario_key]) if params[:scenario_key].present?
      scope = scope.where(user_id: params[:owner_id]) if params[:owner_id].present?
      scope = scope.where(status: params[:status]) if params[:status].present? && AiLeadEmployee::EvaluationRun.statuses.key?(params[:status])
      scope = filter_by_result(scope)
      scope = filter_by_offer(scope)
      scope = filter_by_configuration_version(scope)
      scope = filter_by_knowledge_version(scope)
      scope = filter_by_date(scope)
      scope
    end
  end

  def filter_by_result(scope)
    case params[:result]
    when 'passed'
      scope.where(passed: true)
    when 'failed'
      scope.where(automated_passed: false)
    when 'needs_review'
      scope.where(automated_passed: true, passed: false)
    when 'never_run'
      scope.none
    else
      scope
    end
  end

  def filter_by_offer(scope)
    return scope if params[:offer].blank?

    scope.where("expected_results ->> 'offer' = ?", params[:offer])
  end

  def filter_by_configuration_version(scope)
    return scope if params[:configuration_version].blank?

    scope.where("configuration_snapshot ->> 'qualification_config_version' = ?", params[:configuration_version].to_s)
  end

  def filter_by_knowledge_version(scope)
    return scope if params[:knowledge_version].blank?

    scope.where("knowledge_snapshot ->> 'version' = ?", params[:knowledge_version].to_s)
  end

  def filter_by_date(scope)
    scope = scope.where('created_at >= ?', Time.zone.parse(params[:from]).beginning_of_day) if params[:from].present?
    scope = scope.where('created_at <= ?', Time.zone.parse(params[:to]).end_of_day) if params[:to].present?
    scope
  rescue ArgumentError
    scope
  end

  def result_for(run)
    return 'running' if run.running?
    return 'cancelled' if run.cancelled?
    return 'stale_configuration' if run.stale_configuration?
    return 'failed_model_call' if run.failed_model_call?
    return 'passed' if run.passed?
    return 'needs_review' if run.automated_passed?

    'failed'
  end

  def filter_options
    runs = current_account.ai_lead_employee_evaluation_runs.includes(:user)
    {
      scenarios: AiLeadEmployee::Evaluation::ScenarioCatalog.all.pluck(:key, :name).map { |key, name| { key: key, name: name } },
      owners: runs.filter_map(&:user).uniq.map { |user| { id: user.id, name: user.available_name || user.name || user.email } },
      offers: AiLeadEmployee::Evaluation::ScenarioCatalog.all.filter_map { |scenario| scenario[:offer] }.uniq,
      results: %w[passed failed needs_review never_run running cancelled stale_configuration failed_model_call],
      configuration_versions: runs.filter_map { |run| run.configuration_snapshot['qualification_config_version'] }.uniq,
      knowledge_versions: runs.filter_map { |run| run.knowledge_snapshot['version'] }.uniq
    }
  end

  def launch_gate_status
    launch_gate_evaluator.status
  end

  def launch_gate_evaluator
    @launch_gate_evaluator ||= AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: current_account)
  end

  def grade_params
    params.fetch(:grades, {}).permit(
      approved_answer_use: [:passed, :notes, :serious_issue],
      qualification_question_behavior: [:passed, :notes, :serious_issue],
      invention_avoidance: [:passed, :notes, :serious_issue],
      next_step: [:passed, :notes, :serious_issue],
      lead_quality: [:passed, :notes, :serious_issue],
      booking_eligibility: [:passed, :notes, :serious_issue],
      handoff_eligibility: [:passed, :notes, :serious_issue],
      tone: [:passed, :notes, :serious_issue],
      safety: [:passed, :notes, :serious_issue],
      answer_correctness: [:passed, :notes, :serious_issue],
      qualification_correctness: [:passed, :notes, :serious_issue],
      next_action: [:passed, :notes, :serious_issue]
    )
  end

  def correction_params
    params.require(:correction).permit(:title, :question, :answer, :source_kind, :step_index)
  end

  def launch_gate_params
    params.permit(:team_roleplay_completed, :pilot_conversations_reviewed_count, :approval_notes)
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
