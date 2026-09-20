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

  it 'prefers a useful non-financial fit question and skips known facts' do
    selected = described_class.new(questions: questions, evidence: { 'situation' => { 'asserted' => true } }).perform

    expect(selected).to include('key' => 'desired_result', 'prompt' => 'What result would you like?')
  end

  it 'returns nil when every enabled requirement is already known' do
    evidence = questions.index_with { { 'asserted' => true } }.transform_keys { |question| question['key'] }

    expect(described_class.new(questions: questions, evidence: evidence).perform).to be_nil
  end
end
