# frozen_string_literal: true

class AiLeadEmployee::ConversationIntentClassifier
  Result = Struct.new(:intent, :language, keyword_init: true) do
    def safe_conversation?
      %i[greeting language_question acknowledgment qualification_answer generic_safe].include?(intent)
    end

    def risky?
      intent == :risky_question || review_reason.present?
    end

    def review_reason
      return 'angry_question' if intent == :complaint

      'sensitive_question' if %i[refund_request support_request].include?(intent)
    end

    def requires_approved_knowledge?
      %i[business_question risky_question].include?(intent)
    end
  end

  GREETING_TOKENS = %w[hello hi hey habari mambo].freeze
  ACKNOWLEDGMENT_TOKENS = %w[ok okay sawa asante thanks].freeze
  QUALIFICATION_TOKENS = %w[
    business biashara course agency leads lead inquiries customers budget owner founder sales
    biashara maulizo wateja bajeti mmiliki mauzo
  ].freeze
  BUSINESS_QUESTION_TOKENS = %w[
    offer offers service services product online profits details maelezo kuhusu bei
  ].freeze
  RISKY_TOKENS = %w[
    price pricing cost refund guarantee eligibility legal lawsuit contract liability
    medical health bei gharama dhamana kisheria afya
  ].freeze
  PERSONAL_ACCESS_QUESTION_PATTERN = /\bwhy (?:am i unable to|can t i) (?:access|log in|sign in)\b/
  HUMAN_REQUEST_PATTERNS = [
    /\bi (?:want|need) (?:a|an) (?:human|person|operator|agent|representative)\b/,
    /\bplease give me (?:a |an )?(?:human|person|operator|agent|representative)\b/,
    /\bplease (?:connect|transfer) me (?:to|with) (?:a |an |the |your )?(?:human|person|operator|agent|representative)\b/,
    /\b(?:please[ ]let[ ]me|let[ ]me|i[ ](?:want|need|would[ ]like)[ ]to|can[ ]i|could[ ]i|may[ ]i)
      [ ](?:speak|talk|chat)[ ](?:to|with)[ ](?:a[ ]|an[ ]|the[ ]|your[ ])?
      (?:human|person|operator|agent|sales[ ]representative|representative|team)\b/x,
    /\b(?:nataka|naomba|ningependa|nahitaji)[ ](?:kuongea|kuzungumza|kuwasiliana)
      [ ]na[ ](?:mtu|binadamu|mfanyakazi|timu|mwakilishi)\b/x
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
    requested_intent || content_intent
  end

  def content_intent
    return :risky_question if risky_question?
    return :language_question if language_question?
    return :greeting if greeting?
    return :acknowledgment if acknowledgment?
    return :qualification_answer if qualification_answer?
    return :business_question if business_question?

    :generic_safe
  end

  def requested_intent
    return :complaint if complaint?
    return :refund_request if refund_request?
    return :support_request if support_request?

    :human_request if human_request?
  end

  def complaint?
    requested?(/\b(my complaint|i have a complaint|i want to complain)\b/) ||
      requested?(/\bi (?:am|m) (?:angry|furious|upset)\b/) ||
      requested?(/\b(?:this|your (?:service|course|product|support)) (?:is|was) (?:terrible|unacceptable|a scam)\b/) ||
      requested?(/\b(nina malalamiko|malalamiko yangu|nataka kulalamika|huu ni utapeli)\b/)
  end

  def refund_request?
    requested?(/\b(refund (?:my|me)|i (?:want|need|request) (?:a |my )?refund)\b/) ||
      requested?(/\b(?:nataka|naomba) (?:kurudishiwa|kurejeshewa) (?:fedha|pesa)\b/)
  end

  def support_request?
    requested?(PERSONAL_ACCESS_QUESTION_PATTERN) ||
      requested?(/\b(?:cannot|can t|unable to) (?:access|log in|sign in)\b/) ||
      requested?(/\bsiwezi (?:kuingia|kufungua)\b/) ||
      requested?(/\b(?:please|can you|could you) (?:confirm|verify|check) my payment\b/) ||
      requested?(/\btafadhali (?:thibitisha|hakiki) malipo yangu\b/)
  end

  def human_request?
    HUMAN_REQUEST_PATTERNS.any? { |pattern| requested?(pattern) }
  end

  def requested?(pattern)
    request_text.scan(pattern) do
      prefix = request_text[0...Regexp.last_match.begin(0)]
      return true unless prefix.match?(/\b(not|never|don t)\s*\z/)
    end
    false
  end

  def risky_question?
    token_match?(RISKY_TOKENS)
  end

  def language_question?
    normalized.match?(/\b(do you speak|speak swahili|speak english|can you speak)\b/) ||
      normalized.match?(/\b(unaongea|unaweza)\b.*\b(kiswahili|kiingereza|english)\b/)
  end

  def greeting?
    tokens.any? { |token| GREETING_TOKENS.include?(token) } &&
      (tokens - GREETING_TOKENS - ['there']).empty?
  end

  def qualification_answer?
    token_match?(QUALIFICATION_TOKENS) && !question?
  end

  def acknowledgment?
    normalized == 'thank you' || (tokens.present? && (tokens - ACKNOWLEDGMENT_TOKENS).empty?)
  end

  def business_question?
    question? || token_match?(BUSINESS_QUESTION_TOKENS)
  end

  def question?
    information_request? || message.include?('?') || normalized.match?(/\b(what|how|when|where|why|nini|je)\b/) ||
      without_greeting(normalized).match?(/\A(can|do|does|is|are)\b/)
  end

  def information_request?
    requested?(/\b(?:tell me (?:more )?about|(?:explain|describe) (?:your|this|the))\b/)
  end

  def token_match?(expected_tokens)
    tokens.intersect?(expected_tokens)
  end

  def tokens
    @tokens ||= normalized.delete('?').split
  end

  def normalized
    @normalized ||= normalize(message)
  end

  def request_text
    @request_text ||= message.gsub(/"[^"]*"|“[^”]*”|‘[^’]*’|(?<![[:alnum:]])'[^']*'/, ' ')
                             .split(/(?<=[.!?;])\s+|\n+/)
                             .map { |sentence| without_greeting(normalize(sentence)) }
                             .reject { |sentence| informational_sentence?(sentence) }
                             .join(' ')
  end

  def normalize(value)
    value.downcase.gsub(/[^[:alnum:]\s?]/, ' ').squish
  end

  def without_greeting(value)
    value.split.drop_while { |token| GREETING_TOKENS.include?(token) }.join(' ')
  end

  def informational_sentence?(sentence)
    return false if sentence.match?(PERSONAL_ACCESS_QUESTION_PATTERN)
    return false if sentence.match?(/\Ahow (?:can|could|may) i (?:speak|talk|chat) (?:to|with)\b/)

    sentence.match?(/\A(what|how|when|where|why|does|do|is|are|if)\b/)
  end
end
