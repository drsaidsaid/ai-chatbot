# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Evaluation Sandbox API', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_admin) { create(:user, :administrator, account: other_account) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/evaluation_sandbox" }

  it 'is admin-only' do
    get endpoint, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{endpoint}/runs", headers: agent.create_new_auth_token, params: { scenario_key: 'approved_answer' }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'keeps runs and approvals tenant-scoped' do
    run = create(:ai_lead_employee_evaluation_run, account: account, user: admin)

    post "#{endpoint}/runs/#{run.id}/grade",
         headers: other_admin.create_new_auth_token,
         params: { grades: passing_grades },
         as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(run.reload).to be_pending_review
  end

  it 'runs a scenario, records reviewer grades, and returns the launch gate report' do
    runner = instance_double(AiLeadEmployee::Evaluation::SandboxRunner)
    allow(AiLeadEmployee::Evaluation::SandboxRunner).to receive(:new).and_return(runner)
    allow(runner).to receive(:perform).and_return(
      AiLeadEmployee::Evaluation::SandboxRunner::Result.new(
        run: create(:ai_lead_employee_evaluation_run, account: account, user: admin, scenario_key: 'approved_answer')
      )
    )

    post "#{endpoint}/runs", headers: admin.create_new_auth_token, params: { scenario_key: 'approved_answer' }, as: :json
    expect(response).to have_http_status(:created)
    run_id = response.parsed_body.fetch('id')

    post "#{endpoint}/runs/#{run_id}/grade", headers: admin.create_new_auth_token, params: { grades: passing_grades }, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('review_status' => 'reviewed', 'reviewer_decision' => include('passed' => true))

    get "#{endpoint}/launch_gate", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('ready_for_approval' => false, 'live_ai_enabled' => false)
  end

  def passing_grades
    AiLeadEmployee::EvaluationRun::GRADE_KEYS.index_with { |_key| { passed: true, notes: '' } }
  end
end
