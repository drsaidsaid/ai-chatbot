# frozen_string_literal: true

class AiLeadEmployee::InformationRequest
  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  POLITE_TOKENS = %w[please tafadhali].freeze
  QUESTION_STARTERS = %w[
    can could do does is are what how when where why which who
    je jinsi lini nini wapi
  ].freeze

  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message.to_s
  end

  def call
    message.include?('?') || clauses.any? { |clause| request_clause?(clause) }
  end

  private

  attr_reader :message

  def clauses
    message.split(/[.!;]+/).filter_map do |clause|
      value = normalize(clause)
      value.presence
    end
  end

  def request_clause?(clause)
    value = without_preamble(clause)
    QUESTION_STARTERS.include?(value.split.first) || value.match?(/\A(?:tell me|explain|describe|niambie)\b/) ||
      value.match?(/\Ai am interested\b.*\b(?:i am )?(?:not sure|unsure) (?:where|how|what)\b/)
  end

  def normalize(value)
    value.downcase.gsub(/[^[:alnum:]\s?]/, ' ').squish
  end

  def without_preamble(value)
    value.split.drop_while { |token| GREETING_TOKENS.include?(token) || POLITE_TOKENS.include?(token) }.join(' ')
  end
end
