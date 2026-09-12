# frozen_string_literal: true

require_relative 'qualification_budget_clauses'
require_relative 'qualification_budget_tail'
require_relative 'qualification_observation'
require_relative 'qualification_urgency_extractor'
require_relative 'qualification_contact_extractor'

class AiLeadEmployee::QualificationEvidenceExtractor
  NEGATIVE_VALUES = ['no business', 'no need', 'not urgent', 'not decision maker', 'no budget'].freeze
  POLARITY_FOR_VALUE = NEGATIVE_VALUES.index_with('negative').merge('unknown' => 'unknown').freeze
  UNKNOWN = /\b(?:not sure|do not know|don't know|dont know|unknown|undecided|not decided|not set|sijui|sina uhakika)\b/
  ACKNOWLEDGEMENTS = /\A(?:hello|hi|hey|habari|mambo|thanks|thank you|asante|okay|ok|sawa|yes|no|ndiyo|ndio|hapana)[.!]*\z/
  BUSINESS_ASSERTION = Regexp.union(
    /\b(?:i|we) (?:run|own|operate|have) (?:[\p{L}-]+\s+){0,6}(?:business|company)\b/,
    /\b(?:nina|ninaendesha|naendesha|nafanya)\b.*\b(?:biashara|saluni|kliniki|ushauri|kufundisha)\b/
  )
  BUSINESS_DENIAL = Regexp.union(
    /\b(?:do not|don't|dont) (?:have|run|own|operate) (?:[\p{L}-]+\s+){0,6}(?:business|company|agency|clinic|salon)\b/,
    /\bno business\b|\b(?:sina|hakuna) biashara\b/
  )
  CONTEXT_EXTRACTORS = {
    'decision_authority' => :contextual_authority, 'budget' => :contextual_budget,
    'lead_volume' => :contextual_volume, 'contact_details' => :contextual_contact,
    'business_type' => :contextual_description, 'problem' => :contextual_description,
    'urgency' => :extract_urgency
  }.freeze

  def initialize(content, answered_signal: nil)
    @content = content.to_s.downcase.strip
    @answered_signal = answered_signal.to_s
  end

  # The display-value API is retained for callers that do not need semantics.
  def evidence
    facts = clause_evidence
    add_budget_evidence(facts)
    contextual = contextual_answer if facts.empty?
    facts[answered_signal] = contextual if contextual.present?
    facts
  end

  def observations
    evidence.to_h do |signal, value|
      [signal, AiLeadEmployee::QualificationObservation.new(signal: signal, value: value, budget_basis: @budget_basis).value]
    end
  end

  def self.normalize(signal:, value:)
    return { 'value' => value.to_s, 'polarity' => value.present? ? 'positive' : 'unknown' } if signal.to_s == 'name'

    new(value, answered_signal: signal).observations.fetch(signal.to_s, { 'polarity' => 'unknown' }).merge('value' => value.to_s)
  end

  private

  attr_reader :content, :answered_signal

  def clause_evidence
    clauses.each_with_object({}) do |clause, result|
      next if question?(clause)

      extractors.each do |signal, extractor|
        value = extractor.call(clause)
        result[signal] = value if value.present?
      end
    end
  end

  def add_budget_evidence(facts)
    budget_statements.each do |statement|
      next if question?(statement)

      value = extract_budget(statement)
      facts['budget'] = value if value.present?
    end
  end

  def independent_budget_tail?(text)
    return false if question?(text)

    AiLeadEmployee::QualificationBudgetTail.independent?(text) { |extractor| send(extractor, text) }
  end

  def budget_statements
    @budget_statements ||= AiLeadEmployee::QualificationBudgetClauses.for(content, independent_statement: method(:independent_budget_tail?))
  end

  def clauses
    budget_statements.flat_map do |statement|
      if AiLeadEmployee::QualificationBudgetEvidenceExtractor.financial_statement?(statement)
        # A retained tail depends on the financial claim. It cannot independently
        # establish a business problem, decision authority or another buying fact.
        statement = statement.split(/\b(?:but|lakini)\b/, 2).first
      end
      statement.split(/\b(?:but|lakini)\b/).map(&:strip).reject(&:empty?)
    end
  end

  def question?(text)
    text.include?('?') || text.match?(/\A(?:are you|is your|who |how |je\b|nani\b|(?:please\s+)?(?:tell\s+me|explain)\b)/)
  end

  def extractors
    {
      'business_type' => method(:extract_business_type),
      'problem' => method(:extract_problem),
      'lead_volume' => method(:extract_lead_volume),
      'urgency' => method(:extract_urgency),
      'decision_authority' => method(:extract_decision_authority),
      'contact_details' => method(:extract_contact_details)
    }
  end

  def extract_business_type(text)
    return 'no business' if text.match?(BUSINESS_DENIAL)
    return 'unknown' if unknown_about?(text, /\b(?:business|biashara)\b/)

    business = text.match(/\b(?:my|our|run an?|own an?) (agency|clinic|salon)\b/)&.[](1)
    return business if business
    return 'business' if text.match?(/\b(?:my|our) (?:business|company)\b/)
    return text if text.match?(BUSINESS_ASSERTION)
  end

  def extract_problem(text)
    return 'no need' if text.match?(Regexp.union(
                                      /\b(?:do not|don't|dont) have (?:a |any )?problem\b|\b(?:need|want) no help\b/,
                                      /\b(?:do not|don'?t) need\b(?! approval\b)|\bno (?:problem|need)\b|\b(?:sihitaji|sina (?:shida|changamoto))\b/
                                    ))
    return 'unknown' if unknown_about?(text, /\b(?:problem|need|shida|changamoto)\b/)
    return if approval_only?(text)
    return text if text.match?(/\b(?:problem|struggle|struggling|needs?|help|fix|more (?:leads|inquiries)|nahitaji|changamoto|shida)\b/)
    return text if problem_condition?(text)
    return text if text.match?(/\b(?:nataka|nahitaji)\b.*\b(?:wateja|maulizo|mauzo)\b/)
  end

  def extract_lead_volume(text)
    text.match(/\b\d+\s*(?:leads|inquiries|messages|calls|wateja|maulizo|ujumbe)\b/)&.[](0)
  end

  def approval_only?(text)
    text.match?(/\b(?:need approval|nahitaji idhini)\b/) && !text.match?(/\b(?:problem|sales|wateja|changamoto|shida)\b/)
  end

  def extract_urgency(text = content)
    AiLeadEmployee::QualificationUrgencyExtractor.new(answered_signal: answered_signal).value(text)
  end

  def extract_budget(text)
    budget_value(text)
  end

  def budget_value(text, contextual: false)
    extractor = AiLeadEmployee::QualificationBudgetEvidenceExtractor.new(text, contextual: contextual)
    value = extractor.value
    @budget_basis = extractor.basis if value.present?
    value
  end

  def extract_decision_authority(text)
    return 'unknown' if unknown_about?(text, /\b(?:decid\w*|owner|authori\w*|approv\w*|uamuzi|mamlaka)\b/)

    if text.match?(/\b(?:cannot|can't|cant|do not|don't|dont) decide\b|\b(?:do not|don't|dont) make\b.*\bdecisions?\b|\bsifanyi (?:maamuzi|uamuzi)\b/)
      return 'not decision maker'
    end
    return 'not decision maker' if text.match?(/\bnot (?:the |an? )?(?:decision maker|owner)\b/)
    return 'not decision maker' if text.match?(/\b(?:si|sio) (?:mmiliki|mwenye maamuzi)\b|\b(?:nahitaji idhini|sina mamlaka|niulize bosi)\b/)

    approval = approval_authority(text)
    return approval if approval
    return 'decision maker' if text.match?(Regexp.union(
                                             /\bi (?:own|decide|can decide)\b|\b(?:i am|i'm|am) (?:the |an? )?(?:owner|founder|ceo|decision maker)\b/,
                                             /\b(?:mimi ni mmiliki|mimi ndiye mmiliki|ninaamua|nafanya uamuzi)\b/
                                           ))
  end

  def approval_authority(text)
    return 'not decision maker' if text.gsub(/\b(?:do not|don't|dont) need approval\b/, '').match?(/\b(?:need approval|ask my boss)\b/)

    statement = text.match(/\b(?:i am|i'm|we are) (not )?authori[sz]ed to (?:approve|spend|decide)\b/)
    statement && (statement[1] ? 'not decision maker' : 'decision maker')
  end

  def extract_contact_details(text)
    AiLeadEmployee::QualificationContactExtractor.value(text)
  end

  def contextual_answer
    extractor = CONTEXT_EXTRACTORS[answered_signal]
    return if extractor.nil? || clauses.any? { |clause| question?(clause) }
    return 'unknown' if content.match?(UNKNOWN)

    send(extractor)
  end

  def unknown_about?(text, topic)
    text.match?(UNKNOWN) && text.match?(topic)
  end

  def contextual_volume
    content.delete_suffix('.') if content.match?(/\A\d+\.?\z/)
  end

  def contextual_contact
    extract_contact_details("phone #{content}")
  end

  def contextual_description
    content if content.split.size.between?(1, 30) && content.match?(/[[:alpha:]]/) && !content.match?(ACKNOWLEDGEMENTS)
  end

  def problem_condition?(text)
    text.match?(/\b(?:inquiries|leads|sales|responses|customers|replies|wateja|mauzo|majibu)\b/) &&
      text.match?(/\b(?:low|slow|poor|missed|lost|few|insufficient|declining|polepole|wachache)\b/)
  end

  def contextual_authority
    return 'decision maker' if content.match?(/\A(?:yes|ndiyo|ndio|owner|founder|ceo|decision maker)[.!]*\z/)
    return 'not decision maker' if content.match?(/\A(?:no|hapana|not decision maker)[.!]*\z/)
  end

  def contextual_budget
    budget_value(content, contextual: true)
  end
end
