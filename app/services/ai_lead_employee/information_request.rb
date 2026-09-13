# frozen_string_literal: true

class AiLeadEmployee::InformationRequest
  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  POLITE_TOKENS = %w[please tafadhali].freeze
  CONNECTIVE_TOKENS = %w[and but then na lakini].freeze
  QUESTION_WORDS = %w[what how when where why which who je jinsi lini nini wapi].freeze
  ENGLISH_AUXILIARIES = %w[can could do does is are may should will would].freeze
  ENGLISH_SUBJECTS = %w[i you we they he she it your our this that the there].freeze
  SWAHILI_STARTERS = %w[je jinsi lini mna naweza ninaweza nini unaweza wapi].freeze

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
    compound_clauses.drop(1).find { |clause| request_clause?(clause) }
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
    value.match?(/\A[[:alnum:]'-]+ (?:ina|una|mna|wana)[[:alpha:]]+\b.*\b(?:nini|lini|wapi)\z/) ||
      value.match?(/\Ai am interested\b.*\b(?:i am )?(?:not sure|unsure) (?:where|how|what)\b/)
  end

  def english_auxiliary_question?(tokens)
    ENGLISH_AUXILIARIES.include?(tokens.first) && ENGLISH_SUBJECTS.include?(tokens.second)
  end

  def compound_clauses
    split_clauses(/(?:[.!?;,—–]+|\n+|\b(?:and|but|then|na|lakini)\b)/i)
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
