# frozen_string_literal: true

class AiLeadEmployee::InformationRequest
  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  POLITE_TOKENS = %w[please tafadhali].freeze
  CONNECTIVE_TOKENS = %w[and but then na lakini].freeze
  QUESTION_WORDS = %w[what how when where why which who gani ipi je jinsi lini ngapi nini wapi].freeze
  ENGLISH_AUXILIARIES = %w[can could do does is are may should will would].freeze
  ENGLISH_SUBJECTS = %w[i you we they he she it your our this that the there].freeze
  ENGLISH_REQUEST_VERBS = %w[
    accept allow cost cover deliver have help include integrate offer provide ship start support teach work
  ].freeze
  ENGLISH_COPULAR_PREDICATES = %w[
    available closed eligible included open offered recorded required supported unavailable
  ].freeze
  NON_SUBJECT_TOKENS = (ENGLISH_AUXILIARIES + %w[to]).freeze
  ACKNOWLEDGMENT_TOKENS = %w[yes okay sure correct exactly indeed ndiyo ndio sawa naam ndivyo].freeze
  REPORTED_SPEECH_TOKENS = %w[
    asked asks explained knew know reported reports said says told
  ].freeze
  SWAHILI_REPORTING_STEM = /(?:ambia|eleza|jua|sema|uliza)\z/
  SWAHILI_STARTERS = %w[gani ipi je jinsi lini mna naweza ngapi ninaweza nini unaweza wapi].freeze
  SWAHILI_LANGUAGE_TOKENS = (SWAHILI_STARTERS + %w[bei huduma ina inaanza inajumuisha iko kozi siku]).freeze

  def self.call(message, configured_names: [])
    new(message, configured_names: configured_names).call
  end

  def self.substantive_followup?(message, configured_names: [])
    new(message, configured_names: configured_names).substantive_followup?
  end

  def self.substantive_followup(message, configured_names: [])
    new(message, configured_names: configured_names).substantive_followup
  end

  def initialize(message, configured_names: [])
    @message = message.to_s
    @configured_names = configured_names.compact_blank
  end

  def call
    message.include?('?') || clauses.any? { |clause| request_clause?(clause) }
  end

  def substantive_followup?
    substantive_followup.present?
  end

  def substantive_followup
    acknowledgment_followup || whole_message_request || compound_clauses.drop(1).find { |clause| request_clause?(clause) }
  end

  private

  attr_reader :configured_names, :message

  def clauses
    split_clauses(/(?:[.!?;,—–]+|\n+)/)
  end

  def whole_message_request
    message.strip if configured_conjunction_name_match? && request_clause?(message)
  end

  def configured_conjunction_name_match?
    configured_names.any? do |name|
      normalized_name = normalize(name)
      normalized_name.split.intersect?(CONNECTIVE_TOKENS) && normalize(message).match?(/\b#{Regexp.escape(normalized_name)}\b/)
    end
  end

  def request_clause?(clause)
    value = without_preamble(normalize(clause))
    tokens = value.split
    direct_question?(value, tokens, clause) || terminal_question?(value)
  end

  def direct_question?(value, tokens, raw_clause)
    QUESTION_WORDS.include?(tokens.first) || english_auxiliary_question?(tokens, raw_clause) ||
      SWAHILI_STARTERS.include?(tokens.first) || value.match?(/\Amna[[:alpha:]]{3,}\b/) ||
      value.match?(/\A(?:tell me|explain|describe|niambie)\b/) || value.match?(/\Ani (?:jinsi|lini|nini|wapi)\b/)
  end

  def terminal_question?(value)
    swahili_terminal_question?(value) ||
      value.match?(/\Ai am interested\b.*\b(?:i am )?(?:not sure|unsure) (?:where|how|what)\b/)
  end

  def swahili_terminal_question?(value)
    match = value.match(
      /\A(?<subject>.+\s)(?:(?:ina|una|mna|wana)[[:alpha:]]*|iko|ni)\b.*\b(?:gani|ipi|lini|[[:alpha:]]*ngapi|nini|wapi)\z/
    )
    match && (configured_subject?(match[:subject]) || significant_reported_speech_absent?(match[:subject]))
  end

  def significant_reported_speech_absent?(subject)
    tokens = subject.split
    !tokens.intersect?(REPORTED_SPEECH_TOKENS) && tokens.none? { |token| token.match?(SWAHILI_REPORTING_STEM) }
  end

  def english_auxiliary_question?(tokens, raw_clause)
    return false unless ENGLISH_AUXILIARIES.include?(tokens.first)
    return true if explicit_english_subject_question?(tokens)

    predicate_index = english_predicate_index(tokens)
    return false unless predicate_index && predicate_index <= 5
    return false if ambiguous_capitalized_name?(raw_clause, tokens.first, predicate_index)

    subject_tokens = tokens[1...predicate_index]
    subject_tokens.present? && !subject_tokens.intersect?(NON_SUBJECT_TOKENS)
  end

  def explicit_english_subject_question?(tokens)
    ENGLISH_SUBJECTS.include?(tokens.second) || configured_english_subject_question?(tokens)
  end

  def configured_english_subject_question?(tokens)
    configured_names.any? do |name|
      name_tokens = normalize(name).split
      predicate = tokens[1 + name_tokens.length]
      tokens[1, name_tokens.length] == name_tokens && english_predicates(tokens.first).include?(predicate)
    end
  end

  def english_predicate_index(tokens)
    tokens.each_index.drop(2).find { |index| english_predicates(tokens.first).include?(tokens[index]) }
  end

  def english_predicates(auxiliary)
    auxiliary.in?(%w[is are]) ? ENGLISH_COPULAR_PREDICATES : ENGLISH_REQUEST_VERBS
  end

  def ambiguous_capitalized_name?(raw_clause, auxiliary, predicate_index)
    return false unless auxiliary.in?(%w[may will]) && predicate_index > 2

    raw_clause.to_s.strip.scan(/[[:alpha:]'-]+/).first(2).all? { |word| word.match?(/\A[[:upper:]]/) }
  end

  def configured_subject?(subject)
    configured_names.any? { |name| normalize(name) == normalize(subject) }
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
    followup = match&.[](:followup)&.strip&.sub(/\A(?:and|but|then|na|lakini)\b[\s,;:—–-]*/i, '')
    followup = followup&.sub(/[.!?]+\z/, '')
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
