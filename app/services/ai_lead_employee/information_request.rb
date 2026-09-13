# frozen_string_literal: true

class AiLeadEmployee::InformationRequest
  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze

  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message.to_s
  end

  def call
    information_request? || message.include?('?') || normalized.match?(/\b(what|how|when|where|why|nini|je)\b/) ||
      without_greeting.match?(/\A(can|do|does|is|are)\b/)
  end

  private

  attr_reader :message

  def information_request?
    normalized.match?(/\b(?:tell me (?:more )?about|(?:explain|describe) (?:your|this|the))\b/)
  end

  def normalized
    @normalized ||= message.downcase.gsub(/[^[:alnum:]\s?]/, ' ').squish
  end

  def without_greeting
    normalized.split.drop_while { |token| GREETING_TOKENS.include?(token) }.join(' ')
  end
end
