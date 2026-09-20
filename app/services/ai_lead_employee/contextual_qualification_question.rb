# frozen_string_literal: true

class AiLeadEmployee::ContextualQualificationQuestion
  PURPOSE_PRIORITY = { 'fit' => 0, 'readiness' => 1, 'action_eligibility' => 2 }.freeze

  def initialize(questions:, evidence:, assessment:)
    @questions = questions
    @evidence = evidence || {}
    @assessment = assessment || {}
  end

  def perform
    return if assessment.dig('fit', 'status') == 'not_met'

    questions.select { |question| eligible?(question) }
             .min_by { |question| priority(question) }
  end

  private

  attr_reader :assessment, :evidence, :questions

  def eligible?(question)
    question['enabled'] != false && missing_fields.include?(question['key']) && unanswered?(question['key'])
  end

  def missing_fields
    @missing_fields ||= assessment.values.flat_map { |dimension| Array(dimension['missing_fields']) }.uniq
  end

  def unanswered?(key)
    fact = evidence[key]
    fact.blank? || fact['asserted'] == false || fact['polarity'] == 'unknown'
  end

  def priority(question)
    [PURPOSE_PRIORITY.fetch(question.fetch('purpose', 'fit'), 3), question['answer_type'] == 'money' ? 1 : 0,
     question.fetch('position', 0)]
  end
end
