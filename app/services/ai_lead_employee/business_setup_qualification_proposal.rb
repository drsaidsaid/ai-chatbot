# frozen_string_literal: true

class AiLeadEmployee::BusinessSetupQualificationProposal
  EXPLANATORY_NEGATION_PATTERN = /\b(?:does\s+not|do\s+not|doesn't|don't|cannot|can't)\s+(?:automatically\s+)?(?:mean|make|guarantee|imply)\b/i
  COMPLEX_QUALIFICATION_PATTERN = %r{
    \b(?:lead|customer|client|fit|eligible|suitable)\b.*
    \b(?:or|and/or)\b.*\b(?:no\s+business|revenue|income|salary)\b
  }ix
  SALES_CALL_AGREEMENT_PATTERN = /
    \b(?:sales\s+call|discovery\s+call|simu\s+ya\s+mauzo)\b.*\b(?:requires?|needs?)\b.*
    \b(?:their|lead|customer)?\s*agreement\b
  /ix

  def self.explanatory_negation?(sentence) = sentence.match?(EXPLANATORY_NEGATION_PATTERN)

  def self.complex?(sentence) = sentence.match?(COMPLEX_QUALIFICATION_PATTERN)

  def self.any_complex?(sentences) = Array(sentences).any? { |sentence| complex?(sentence) }

  def self.any_complex_text?(text)
    any_complex?(text.to_s.split(/(?<=[.!?])\s+|\n+/))
  end

  def self.question(sentence:, position:)
    return sales_call_agreement_question if sentence.match?(SALES_CALL_AGREEMENT_PATTERN)

    generated_question(sentence, position)
  end

  def self.sales_call_agreement_question
    {
      'key' => 'sales_call_agreement', 'meaning' => 'Sales call agreement', 'answer_type' => 'boolean',
      'prompt' => 'Would you like a sales call?', 'enabled' => true, 'required' => true,
      'purpose' => 'action_eligibility'
    }
  end
  private_class_method :sales_call_agreement_question

  def self.generated_question(sentence, position)
    key = "setup_fit_#{Digest::SHA256.hexdigest(sentence)[0, 10]}"
    trimmed = sentence.sub(/[.!?]+\z/, '')
    requirement = trimmed.sub(/^.*?\b(?:requires?|needs?)\s+/i, '')
    prompt = requirement == trimmed ? "Please confirm: #{trimmed}." : "Do you have #{requirement}?"
    {
      'key' => key, 'meaning' => sentence.truncate(120), 'answer_type' => 'boolean', 'prompt' => prompt,
      'position' => position, 'enabled' => true, 'required' => true,
      'purpose' => action_rule?(sentence) ? 'action_eligibility' : 'fit'
    }
  end
  private_class_method :generated_question

  def self.action_rule?(sentence) = sentence.match?(/\b(call|purchase|buy|appointment|book|simu|ununuzi|miadi)\b/i)
  private_class_method :action_rule?
end
