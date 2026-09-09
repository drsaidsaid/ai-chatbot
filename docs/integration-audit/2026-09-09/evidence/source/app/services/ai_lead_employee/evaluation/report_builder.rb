# frozen_string_literal: true

class AiLeadEmployee::Evaluation::ReportBuilder
  def initialize(account:)
    @account = account
  end

  def perform
    {
      'required_scenarios' => required_scenarios,
      'scenario_results' => scenario_results,
      'reviewed_qualification_accuracy' => reviewed_qualification_accuracy,
      'minimum_qualification_accuracy' => AiLeadEmployee::LaunchGate::MINIMUM_QUALIFICATION_ACCURACY,
      'serious_issue_count' => serious_issue_count,
      'latest_runs_count' => latest_reviewed_runs.size,
      'ready_for_approval' => ready_for_approval?,
      'blocking_reasons' => blocking_reasons
    }
  end

  private

  attr_reader :account

  def required_scenarios
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys
  end

  def scenario_results
    required_scenarios.to_h do |scenario_key|
      latest = latest_reviewed_run_for(scenario_key)
      [scenario_key, {
        'reviewed' => latest.present?,
        'passed' => latest&.passed? || false,
        'run_id' => latest&.id,
        'created_at' => latest&.created_at&.iso8601
      }]
    end
  end

  def ready_for_approval?
    missing_required_scenarios.blank? &&
      reviewed_qualification_accuracy.to_f >= AiLeadEmployee::LaunchGate::MINIMUM_QUALIFICATION_ACCURACY &&
      serious_issue_count.zero?
  end

  def blocking_reasons
    [].tap do |reasons|
      reasons << "Missing passing reviews for #{missing_required_scenarios.join(', ')}" if missing_required_scenarios.present?
      if reviewed_qualification_accuracy.to_f < AiLeadEmployee::LaunchGate::MINIMUM_QUALIFICATION_ACCURACY
        reasons << 'Reviewed qualification accuracy is below 85%'
      end
      reasons << 'Serious fabricated, harmful, or policy-breaking answers must be zero' if serious_issue_count.positive?
    end
  end

  def missing_required_scenarios
    scenario_results.filter_map { |scenario_key, result| scenario_key unless result['reviewed'] && result['passed'] }
  end

  def latest_reviewed_run_for(scenario_key)
    AiLeadEmployee::EvaluationRun.reviewed.where(account: account, scenario_key: scenario_key).latest_first.first
  end

  def latest_reviewed_runs
    @latest_reviewed_runs ||= required_scenarios.filter_map { |scenario_key| latest_reviewed_run_for(scenario_key) }
  end

  def reviewed_qualification_accuracy
    applicable = latest_reviewed_runs.flat_map(&:steps).select { |step| step.dig('expected', 'quality').present? }
    return 0.0 if applicable.blank?

    (applicable.count { |step| step.dig('qualification', 'quality') == step.dig('expected', 'quality') }.to_f / applicable.size).round(2)
  end

  def serious_issue_count
    latest_reviewed_runs.sum(&:serious_issue_count)
  end
end
