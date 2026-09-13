# frozen_string_literal: true

class AiLeadEmployee::InformationRequest
  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  POLITE_TOKENS = %w[please tafadhali].freeze
  CONNECTIVE_TOKENS = %w[and but then na lakini].freeze
  QUESTION_WORDS = %w[what how when where why which who gani ipi je jinsi lini nini wapi].freeze
  ENGLISH_AUXILIARIES = %w[can could do does is are may should will would].freeze
  ENGLISH_SUBJECTS = %w[i you we they he she it your our this that the there].freeze
  ENGLISH_REQUEST_VERBS = %w[
    accept allow cost cover deliver have help include integrate offer provide ship start support teach work
  ].freeze
  ACKNOWLEDGMENT_TOKENS = %w[yes okay sure correct exactly indeed ndiyo ndio sawa naam ndivyo].freeze
  REPORTED_SPEECH_TOKENS = %w[
    alieleza alisema aliuliza asked explained knew know said says told walieleza walisema waliuliza
  ].freeze
  SWAHILI_STARTERS = %w[gani ipi je jinsi lini mna naweza ninaweza nini unaweza wapi].freeze

  def self.call(message)
    new(message).call
  end

  def self.substantive_followup?(message)
    new(message).substantive_followup?
  end

  def self.substantive_followup(message)
    new(message).substantive_followup
  end

  def initialize(message)
    @message = message.to_s
  end

  def call
    message.include?('?') || clauses.any? { |clause| request_clause?(clause) }
  end

  def substantive_followup?
    substantive_followup.present?
  end

  def substantive_followup
    compound_clauses.drop(1).find { |clause| request_clause?(clause) } || acknowledgment_followup
  end

  private

  attr_reader :message

  def clauses
    split_clauses(/(?:[.!?;,—–]+|\n+)/)
  end

  def request_clause?(clause)
    value = without_preamble(normalize(clause))
    tokens = value.split
    direct_question?(value, tokens) || terminal_question?(value)
  end

  def direct_question?(value, tokens)
    QUESTION_WORDS.include?(tokens.first) || english_auxiliary_question?(tokens) ||
      SWAHILI_STARTERS.include?(tokens.first) || value.match?(/\Amna[[:alpha:]]{3,}\b/) ||
      value.match?(/\A(?:tell me|explain|describe|niambie)\b/) || value.match?(/\Ani (?:jinsi|lini|nini|wapi)\b/)
  end

  def terminal_question?(value)
    swahili_terminal_question?(value) ||
      value.match?(/\Ai am interested\b.*\b(?:i am )?(?:not sure|unsure) (?:where|how|what)\b/)
  end

  def swahili_terminal_question?(value)
    match = value.match(
      /\A(?<subject>(?:[[:alnum:]'-]+\s){1,4})(?:(?:ina|una|mna|wana)[[:alpha:]]+|iko|ni)\b.*\b(?:gani|ipi|nini|lini|wapi)\z/
    )
    match && significant_reported_speech_absent?(match[:subject])
  end

  def significant_reported_speech_absent?(subject)
    !subject.split.intersect?(REPORTED_SPEECH_TOKENS)
  end

  def english_auxiliary_question?(tokens)
    return false unless ENGLISH_AUXILIARIES.include?(tokens.first)
    return true if ENGLISH_SUBJECTS.include?(tokens.second)

    predicate_index = tokens.each_index.drop(2).find { |index| ENGLISH_REQUEST_VERBS.include?(tokens[index]) }
    return false unless predicate_index

    subject_tokens = tokens[1...predicate_index]
    subject_tokens.present? && subject_tokens.size <= 4 && !subject_tokens.intersect?(ENGLISH_AUXILIARIES)
  end

  def compound_clauses
    clauses.flat_map { |clause| split_request_followup(clause) }.compact_blank
  end

  def split_request_followup(clause)
    clause.to_enum(:scan, /\b(?:and|but|then|na|lakini)\b/i).each do
      boundary = Regexp.last_match
      followup = clause[boundary.end(0)..].to_s.strip
      return [clause[0...boundary.begin(0)].strip, followup] if request_clause?(followup)
    end

    [clause]
  end

  def acknowledgment_followup
    match = message.match(/\A\s*(?:#{ACKNOWLEDGMENT_TOKENS.join('|')})\b[\s,;:—–-]+(?<followup>.+)\z/i)
    followup = match&.[](:followup)&.strip
    followup if followup.present? && request_clause?(followup)
  end

  def split_clauses(pattern)
    message.split(pattern).filter_map do |clause|
      clause.strip.presence
    end
  end

  def normalize(value)
    value.downcase.gsub(/[^[:alnum:]\s?]/, ' ').squish
  end

  def without_preamble(value)
    value.split.drop_while do |token|
      GREETING_TOKENS.include?(token) || POLITE_TOKENS.include?(token) || CONNECTIVE_TOKENS.include?(token)
    end.join(' ')
  end
end
