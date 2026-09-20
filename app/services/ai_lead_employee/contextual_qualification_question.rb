# frozen_string_literal: true

class AiLeadEmployee::ContextualQualificationQuestion
  PURPOSE_PRIORITY = { 'fit' => 0, 'readiness' => 1, 'action_eligibility' => 2 }.freeze

  def initialize(questions:, evidence:)
    @questions = questions
    @evidence = evidence || {}
  end

  def perform
    questions.select { |question| question['enabled'] != false && unanswered?(question['key']) }
             .min_by { |question| priority(question) }
  end

  private

  attr_reader :evidence, :questions

  def unanswered?(key)
    fact = evidence[key]
    fact.blank? || fact['asserted'] == false || fact['polarity'] == 'unknown'
  end

  def priority(question)
    [PURPOSE_PRIORITY.fetch(question.fetch('purpose', 'fit'), 3), question['answer_type'] == 'money' ? 1 : 0,
     question.fetch('position', 0)]
  end
end
