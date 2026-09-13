# frozen_string_literal: true

require_relative 'information_request'

class AiLeadEmployee::ConversationIntentClassifier # rubocop:disable Metrics/ClassLength
  Result = Struct.new(:intent, :language, :scope_question, :scope_message_id, :scope_clarification_consumed, keyword_init: true) do
    def safe_conversation?
      %i[greeting language_question acknowledgment qualification_answer generic_safe unrelated scope_clarification].include?(intent)
    end

    def risky?
      intent == :risky_question || review_reason.present?
    end

    def review_reason
      return 'angry_question' if intent == :complaint

      'sensitive_question' if %i[refund_request support_request].include?(intent)
    end

    def requires_approved_knowledge?
      %i[business_question risky_question personalized_strategy].include?(intent)
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
  UNRELATED_PATTERNS = [
    /\b(?:weather|forecast|football|soccer|match score|recipe|pilau|movie|celebrity|politics|election)\b/,
    /\b(?:hali ya hewa|mpira|mchezo|mapishi|siasa|uchaguzi)\b/
  ].freeze
  PERSONALIZED_STRATEGY_PATTERNS = [
    /\b(?:build|create|write|design|give me) (?:a |an |my )?(?:marketing |sales |business )?(?:strategy|plan|campaign)\b/,
    /\b(?:tell me exactly|what should i do|advise me)\b.{0,60}\b(?:grow|market|sell|business|company)\b/,
    /\b(?:nitengenezee|niandikie|nishauri)\b.{0,60}\b(?:mkakati|mpango|biashara|masoko|mauzo)\b/
  ].freeze
  CONTENT_INTENT_CHECKS = {
    unrelated: :unrelated?,
    risky_question: :risky_question?,
    language_question: :language_question?,
    greeting: :greeting?,
    acknowledgment: :acknowledgment?,
    personalized_strategy: :personalized_strategy?,
    qualification_answer: :qualification_answer?,
    scope_clarification: :scope_clarification?,
    business_question: :business_question?
  }.freeze

  def initialize(message:, account: nil, conversation: nil, incoming_message: nil, offer: nil)
    @message = message.to_s
    @account = account
    @conversation = conversation
    @incoming_message = incoming_message
    @offer = offer
  end

  def perform
    classified_intent = intent
    Result.new(
      intent: classified_intent,
      language: classification_language,
      **scope_result_attributes(classified_intent)
    )
  end

  private

  attr_reader :account, :conversation, :incoming_message, :message, :offer

  def classification_language
    resolved = business_scope_relevance&.resolved_language
    resolved || AiLeadEmployee::LanguageDetector.detect(message)
  end

  def scope_result_attributes(classified_intent)
    resolved = %i[business_question scope_clarification].include?(classified_intent)
    {
      scope_question: resolved ? business_scope_relevance&.resolved_question : nil,
      scope_message_id: resolved ? business_scope_relevance&.resolved_message_id : nil,
      scope_clarification_consumed: business_scope_relevance&.consumes_clarification?
    }
  end

  def intent
    requested_intent || content_intent
  end

  def content_intent
    classified = preclassified_intent
    return classified if classified

    CONTENT_INTENT_CHECKS.find { |_intent, predicate| send(predicate) }&.first || :generic_safe
  end

  def preclassified_intent
    return :qualification_answer if pending_offer_answer?
    return :business_question if resolved_scope_question?
    return :scope_clarification if business_scope_relevance&.reclarification_required?
  end

  def resolved_scope_question?
    business_scope_relevance&.resolved_question.present? && business_scope_relevance.relevant? &&
      !business_scope_relevance.reclarification_required?
  end

  def unrelated?
    return UNRELATED_PATTERNS.any? { |pattern| normalized.match?(pattern) } unless account
    return true if business_scope_relevance.consumes_clarification? && business_scope_relevance.clearly_outside_scope?
    return !business_scope_relevance.addressed_authoritative_scope_match? if unrelated_pattern?
    return false if business_scope_relevance.authoritative_scope_match?

    business_scope_relevance.clearly_outside_scope?
  end

  def unrelated_pattern?
    UNRELATED_PATTERNS.any? { |pattern| normalized.match?(pattern) }
  end

  def scope_clarification?
    account && (question? || business_scope_relevance.reclarification_required?) && business_scope_relevance.ambiguous?
  end

  def business_scope_relevance
    return unless account

    @business_scope_relevance ||= AiLeadEmployee::BusinessScopeRelevance.new(
      account: account, message: message, offer: offer, conversation: conversation, incoming_message: incoming_message
    )
  end

  def personalized_strategy?
    PERSONALIZED_STRATEGY_PATTERNS.any? { |pattern| normalized.match?(pattern) }
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

  def pending_offer_answer?
    return false unless conversation && incoming_message && offer

    AiLeadEmployee::OfferEvidenceRecorder.new(
      conversation: conversation, offer: offer, incoming_message: incoming_message
    ).answers_pending_question?
  end

  def acknowledgment?
    normalized == 'thank you' || (tokens.present? && (tokens - ACKNOWLEDGMENT_TOKENS).empty?)
  end

  def business_question?
    question? || (token_match?(BUSINESS_QUESTION_TOKENS) && !modal_name_declaration?)
  end

  def modal_name_declaration?
    normalized.match?(/\A(?:may|will)\b/) && !question?
  end

  def question?
    account ? business_scope_relevance.information_request? : AiLeadEmployee::InformationRequest.call(message)
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
