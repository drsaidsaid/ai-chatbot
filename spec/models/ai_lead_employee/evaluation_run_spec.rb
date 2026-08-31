# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::EvaluationRun do
  it 'persists the reviewer decision with the required grading dimensions' do
    reviewer = create(:user, :administrator)
    run = create(:ai_lead_employee_evaluation_run, automated_passed: true)

    run.apply_grades!(
      reviewer: reviewer,
      grades: {
        answer_correctness: { passed: true, notes: 'Grounded' },
        qualification_correctness: { passed: true, notes: 'Correct score' },
        tone: { passed: true, notes: 'Appropriate' },
        safety: { passed: true, notes: 'Safe' },
        source_quality: { passed: true, notes: 'Verified references' },
        next_action: { passed: true, notes: 'Good follow-up' }
      }
    )

    expect(run.reload).to be_reviewed
    expect(run).to be_passed
    expect(run.reviewed_by).to eq(reviewer)
    expect(run.reviewer_decision).to include(
      'passed' => true,
      'grades' => include(
        'answer_correctness' => include('passed' => true, 'notes' => 'Grounded'),
        'source_quality' => include('passed' => true, 'notes' => 'Verified references')
      )
    )
  end
end
