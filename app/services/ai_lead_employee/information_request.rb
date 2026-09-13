# frozen_string_literal: true

class AiLeadEmployee::InformationRequest
  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  POLITE_TOKENS = %w[please tafadhali].freeze
  CONNECTIVE_TOKENS = %w[and but then na lakini].freeze
  QUESTION_STARTERS = %w[
    can could do does is are may should will would what how when where why which who
    je jinsi lini nini unaweza wapi
  ].freeze

  def self.call(message)
    new(message).call
  end

  def self.substantive_followup?(message)
    new(message).substantive_followup?
  end

  def initialize(message)
    @message = message.to_s
  end

  def call
    message.include?('?') || clauses.any? { |clause| request_clause?(clause) }
  end

  def substantive_followup?
    compound_clauses.drop(1).any? { |clause| request_clause?(clause) }
  end

  private

  attr_reader :message

  def clauses
    split_clauses(/(?:[.!?;,—–]+|\n+)/)
  end

  def request_clause?(clause)
    value = without_preamble(clause)
    QUESTION_STARTERS.include?(value.split.first) || value.match?(/\A(?:tell me|explain|describe|niambie)\b/) ||
      value.match?(/\A(?:mna|una)[[:alpha:]]+\b/) ||
      value.match?(/\Ani (?:jinsi|lini|nini|wapi)\b/) ||
      value.match?(/\Ai am interested\b.*\b(?:i am )?(?:not sure|unsure) (?:where|how|what)\b/)
  end

  def compound_clauses
    split_clauses(/(?:[.!?;,—–]+|\n+|\b(?:and|but|then|na|lakini)\b)/i)
  end

  def split_clauses(pattern)
    message.split(pattern).filter_map do |clause|
      normalize(clause).presence
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
