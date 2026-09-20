# frozen_string_literal: true

require 'active_support/all'

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/contextual_qualification_question'

RSpec.describe AiLeadEmployee::ContextualQualificationQuestion do
  let(:questions) do
    [
      { 'key' => 'monthly_metric', 'answer_type' => 'money', 'purpose' => 'readiness', 'position' => 0,
        'enabled' => true, 'prompt' => 'What is the current monthly amount?' },
      { 'key' => 'situation', 'answer_type' => 'text', 'purpose' => 'fit', 'position' => 1,
        'enabled' => true, 'prompt' => 'What is your current situation?' },
      { 'key' => 'desired_result', 'answer_type' => 'text', 'purpose' => 'fit', 'position' => 2,
        'enabled' => true, 'prompt' => 'What result would you like?' }
    ]
  end
  let(:assessment) do
    { 'fit' => { 'status' => 'missing', 'missing_fields' => %w[situation desired_result] },
      'readiness' => { 'status' => 'missing', 'missing_fields' => ['monthly_metric'] } }
  end

  it 'prefers a useful non-financial fit question and skips known facts' do
    selected = described_class.new(
      questions: questions, evidence: { 'situation' => { 'asserted' => true } }, assessment: assessment
    ).perform

    expect(selected).to include('key' => 'desired_result', 'prompt' => 'What result would you like?')
  end

  it 'returns nil when every enabled requirement is already known' do
    evidence = questions.index_with { { 'asserted' => true } }.transform_keys { |question| question['key'] }

    expect(described_class.new(questions: questions, evidence: evidence, assessment: assessment).perform).to be_nil
  end

  it 'does not ask fields outside current deterministic missing requirements' do
    completed = { 'fit' => { 'status' => 'met', 'missing_fields' => [] } }

    expect(described_class.new(questions: questions, evidence: {}, assessment: completed).perform).to be_nil
  end

  it 'does not repeat an unanswered branch after its any-of requirement is satisfied' do
    branch_satisfied = {
      'fit' => { 'status' => 'missing', 'missing_fields' => ['desired_result'] },
      'readiness' => { 'status' => 'missing', 'missing_fields' => ['monthly_metric'] }
    }

    selected = described_class.new(questions: questions, evidence: {}, assessment: branch_satisfied).perform

    expect(selected).to include('key' => 'desired_result')
    expect(selected).not_to include('key' => 'situation')
  end

  it 'moves to readiness after current situation and corrected desired result are known' do
    known_fit = {
      'situation' => { 'asserted' => true, 'typed_value' => 'consulting' },
      'desired_result' => { 'asserted' => true, 'typed_value' => 'corrected goal' }
    }
    readiness_missing = {
      'fit' => { 'status' => 'met', 'missing_fields' => [] },
      'readiness' => { 'status' => 'missing', 'missing_fields' => ['monthly_metric'] }
    }

    selected = described_class.new(questions: questions, evidence: known_fit, assessment: readiness_missing).perform

    expect(selected).to include('key' => 'monthly_metric')
  end

  it 'does not escalate into financial discovery after fit is not met' do
    failed = assessment.merge('fit' => { 'status' => 'not_met', 'missing_fields' => [] })

    expect(described_class.new(questions: questions, evidence: {}, assessment: failed).perform).to be_nil
  end
end
