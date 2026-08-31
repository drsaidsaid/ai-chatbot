# frozen_string_literal: true

FactoryBot.define do
  factory :ai_lead_employee_evaluation_run, class: 'AiLeadEmployee::EvaluationRun' do
    account
    user { create(:user, :administrator, account: account) }
    scenario_key { 'approved_answer' }
    scenario_name { 'Approved answer' }
    status { :completed }
    automated_passed { false }
    passed { false }
    review_status { :pending_review }
    messages { [] }
    steps do
      [
        {
          'expected' => { 'quality' => 'low_qualified' },
          'qualification' => { 'quality' => 'low_qualified' },
          'checks' => []
        }
      ]
    end
    grades { {} }
    metrics { { 'serious_issue_count' => 0 } }
    expected_results { {} }
    configuration_snapshot { { 'qualification_config_version' => 1 } }
    knowledge_snapshot { { 'version' => 'factory-knowledge-version', 'items' => [] } }
    provider_snapshot { { 'provider' => nil, 'model' => 'deterministic-test' } }
    prompt_version { AiLeadEmployee::Evaluation::SandboxRunner::PROMPT_VERSION }
    reviewer_decision { {} }
    sequence(:simulation_identifier) { |n| "evaluation-factory-#{n}" }
    completed_at { Time.current }

    trait :reviewed_pass do
      automated_passed { true }
      passed { true }
      review_status { :reviewed }
      reviewed_by { user }
      reviewed_at { Time.current }
      grades do
        AiLeadEmployee::EvaluationRun::GRADE_KEYS.index_with do |_key|
          { 'passed' => true, 'notes' => '', 'serious_issue' => false }
        end
      end
      reviewer_decision do
        {
          'passed' => true,
          'grades' => grades,
          'reviewed_by_id' => user.id,
          'reviewed_at' => Time.current.iso8601
        }
      end
    end
  end
end
