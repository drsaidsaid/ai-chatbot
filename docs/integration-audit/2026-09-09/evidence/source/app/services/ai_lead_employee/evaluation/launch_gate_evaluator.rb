# frozen_string_literal: true

class AiLeadEmployee::Evaluation::LaunchGateEvaluator
  ApprovalBlocked = Class.new(StandardError)

  def initialize(account:)
    @account = account
    @gate = AiLeadEmployee::LaunchGate.for(account)
  end

  def status
    {
      'gate' => gate_payload,
      'report' => report,
      'ready_for_approval' => approval_ready?,
      'live_ai_enabled' => gate.approved? && approval_ready?,
      'blocking_reasons' => blocking_reasons
    }
  end

  def update!(params)
    gate.update!(
      team_roleplay_completed: boolean_param(params, :team_roleplay_completed, gate.team_roleplay_completed),
      pilot_conversations_reviewed_count: params.fetch(:pilot_conversations_reviewed_count, gate.pilot_conversations_reviewed_count).to_i,
      approval_notes: params.fetch(:approval_notes, gate.approval_notes)
    )
    status
  end

  def approve!(user:, notes: nil)
    raise ApprovalBlocked, blocking_reasons.join('; ') unless approval_ready?

    gate.approve!(user: user, report: report.merge('approval_notes' => notes.to_s.presence || gate.approval_notes.to_s))
    status
  end

  def approval_ready?
    report.fetch('ready_for_approval') &&
      gate.team_roleplay_completed? &&
      gate.pilot_conversations_reviewed_count >= AiLeadEmployee::LaunchGate::REQUIRED_PILOT_REVIEWS
  end

  def blocking_reasons
    report.fetch('blocking_reasons').dup.tap do |reasons|
      reasons << 'Team roleplay must be completed' unless gate.team_roleplay_completed?
      if gate.pilot_conversations_reviewed_count < AiLeadEmployee::LaunchGate::REQUIRED_PILOT_REVIEWS
        reasons << "At least #{AiLeadEmployee::LaunchGate::REQUIRED_PILOT_REVIEWS} pilot conversations must be reviewed"
      end
    end
  end

  private

  attr_reader :account, :gate

  def report
    @report ||= AiLeadEmployee::Evaluation::ReportBuilder.new(account: account).perform
  end

  def gate_payload
    {
      'id' => gate.id,
      'team_roleplay_completed' => gate.team_roleplay_completed,
      'pilot_conversations_reviewed_count' => gate.pilot_conversations_reviewed_count,
      'required_pilot_reviews' => AiLeadEmployee::LaunchGate::REQUIRED_PILOT_REVIEWS,
      'approval_notes' => gate.approval_notes,
      'approved' => gate.approved?,
      'approved_by_id' => gate.approved_by_id,
      'approved_at' => gate.approved_at&.iso8601
    }
  end

  def boolean_param(params, key, fallback)
    return fallback unless params.key?(key) || params.key?(key.to_s)

    ActiveModel::Type::Boolean.new.cast(params[key] || params[key.to_s])
  end
end
