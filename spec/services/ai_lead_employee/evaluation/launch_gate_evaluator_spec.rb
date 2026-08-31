# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Evaluation::LaunchGateEvaluator do
  let(:account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }

  it 'blocks approval until all reviewed checks pass' do
    evaluator = described_class.new(account: account)

    expect(evaluator.status).to include('ready_for_approval' => false, 'live_ai_enabled' => false)
    expect { evaluator.approve!(user: admin, notes: 'Ready') }.to raise_error(described_class::ApprovalBlocked)
  end

  it 'records admin approval only after the launch report is ready' do
    create_passing_reviewed_runs
    evaluator = described_class.new(account: account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: AiLeadEmployee::LaunchGate::REQUIRED_PILOT_REVIEWS)

    status = evaluator.approve!(user: admin, notes: 'Approved for controlled pilot')

    expect(status).to include('ready_for_approval' => true, 'live_ai_enabled' => true)
    gate = AiLeadEmployee::LaunchGate.for(account)
    expect(gate).to be_approved
    expect(gate.approved_by).to eq(admin)
    expect(gate.report).to include('approval_notes' => 'Approved for controlled pilot')
  end

  def create_passing_reviewed_runs
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |scenario_key|
      create(:ai_lead_employee_evaluation_run, :reviewed_pass, account: account, user: admin, scenario_key: scenario_key)
    end
  end
end
