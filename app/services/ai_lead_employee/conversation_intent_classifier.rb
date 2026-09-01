# frozen_string_literal: true

class AiLeadEmployee::ConversationIntentClassifier
  Result = Struct.new(:intent, :language, keyword_init: true) do
    def safe_conversation?
      %i[greeting language_question qualification_answer generic_safe].include?(intent)
    end

    def risky?
      intent == :risky_question
    end

    def requires_approved_knowledge?
      %i[business_question risky_question].include?(intent)
    end
  end

  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  ACKNOWLEDGEMENT_TOKENS = %w[ok okay sawa yes ndio ndiyo thanks asante].freeze
  QUALIFICATION_TOKENS = %w[
    business biashara course agency leads lead inquiries customers budget owner founder
    biashara maulizo wateja bajeti mmiliki
  ].freeze
  BUSINESS_QUESTION_TOKENS = %w[
    offer offers service services product online profits details maelezo kuhusu bei
  ].freeze
  RISKY_TOKENS = %w[
    price pricing cost refund guarantee eligibility legal lawsuit contract liability
    medical health bei gharama dhamana kisheria afya
  ].freeze

  def initialize(message:)
    @message = message.to_s
  end

  def perform
    Result.new(intent: intent, language: AiLeadEmployee::LanguageDetector.detect(message))
  end

  private

  attr_reader :message

  def intent
    return :risky_question if risky_question?
    return :language_question if language_question?
    return :greeting if greeting?
    return :qualification_answer if qualification_answer?
    return :business_question if business_question?
    return :generic_safe if acknowledgement?

    :generic_safe
  end

  def risky_question?
    token_match?(RISKY_TOKENS)
  end

  def language_question?
    normalized.match?(/\b(do you speak|speak swahili|speak english|can you speak)\b/) ||
      normalized.match?(/\b(unaongea|unaweza)\b.*\b(kiswahili|kiingereza|english)\b/)
  end

  def greeting?
    tokens.any? { |token| GREETING_TOKENS.include?(token) }
  end

  def qualification_answer?
    token_match?(QUALIFICATION_TOKENS) && !question?
  end

  def business_question?
    question? || token_match?(BUSINESS_QUESTION_TOKENS)
  end

  def acknowledgement?
    tokens.any? { |token| ACKNOWLEDGEMENT_TOKENS.include?(token) }
  end

  def question?
    message.include?('?') || normalized.match?(/\b(what|how|when|where|why|can|do|does|is|are|nini|je)\b/)
  end

  def token_match?(expected_tokens)
    tokens.intersect?(expected_tokens)
  end

  def tokens
    @tokens ||= normalized.split
  end

  def normalized
    @normalized ||= message.downcase.gsub(/[^[:alnum:]\s?]/, ' ').squish
  end
end
