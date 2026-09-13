# frozen_string_literal: true

class AiLeadEmployee::BusinessScopeRelevance
  STOP_WORDS = %w[
    a an and are can do does for from how i in is it my of on or our the this to we what with you your
    hii hiki jinsi kuhusu kwa la na ni unaweza ya yako
  ].freeze
  BUSINESS_EXCHANGE_PATTERNS = [
    /\b(?:
      book(?:ing)?|buy(?:ing)?|checkout|costs?|deliver(?:y|ies)|invoices?|orders?|pay(?:ment|ments|ing)?|prices?|purchas\w*|
      refunds?|register|schedule|shipping|subscribe|subscription
    )\b/x,
    /\b(?:can|could|do|does|will|would)\s+you\b.{0,40}\b(?:
      accept\w*|allow\w*|charg\w*|deliver\w*|includ\w*|integrat\w*|offer\w*|provid\w*|sell\w*|ship\w*|support\w*
    )\b/x,
    /\byour (?:business|company|contact|delivery|hours|location|offer|payment|product|service|shipping)\b/,
    /\b(?:where are you located|what time (?:do you|does the business) open)\b/,
    /\b(?:
      agiza\w*|bei|gharama|jiandik\w*|lipa\w*|malipo|nunua\w*|usafirish\w*
    )\b/x,
    /\b(?:
      (?:mna|una)(?:kubali|pokea|safirisha|tuma|toa|uza|ruhusu)\w*
    )\b/x
  ].freeze

  def initialize(account:, message:, offer: nil)
    @account = account
    @message = message.to_s
    @offer = offer
  end

  def clearly_outside_scope?
    return false unless informational_question?
    return false if configured_scope_match? || approved_scope_match?

    !business_exchange_question?
  end

  private

  attr_reader :account, :message, :offer

  def informational_question?
    message.include?('?') || normalized_message.match?(
      /\A(?:can|could|do|does|how|is|are|what|when|where|which|who|why|je|jinsi|lini|nini|wapi)\b/
    )
  end

  # Keep an unknown in Review when its meaning describes a commercial exchange.
  # Pronouns alone do not make a question relevant to the Business.
  def business_exchange_question?
    BUSINESS_EXCHANGE_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
  end

  def configured_scope_match?
    scope_match?(configured_scope_texts)
  end

  def approved_scope_match?
    scope_match?(approved_scope_texts)
  end

  def scope_match?(texts)
    question_tokens = significant_tokens(message)
    return false if question_tokens.empty?

    texts.any? do |text|
      overlap = question_tokens & significant_tokens(text)
      overlap.size >= [2, question_tokens.size].min
    end
  end

  def configured_scope_texts
    offers = offer ? [offer] : account.qualification_offers.enabled_in_order.to_a
    [account.name, account.settings&.dig('ai_lead_employee', 'default_offer'),
     *offers.map { |candidate| [candidate.name, candidate.configuration].to_json }].compact
  end

  def approved_scope_texts
    @approved_scope_texts ||= AiLeadEmployee::KnowledgeAnswerService.new(
      account: account,
      question: message,
      offer: offer,
      language: AiLeadEmployee::LanguageDetector.detect(message)
    ).approved_scope_texts
  end

  def significant_tokens(value)
    normalize(value).split.reject { |token| token.length < 3 || STOP_WORDS.include?(token) }.uniq
  end

  def normalized_message
    @normalized_message ||= normalize(message)
  end

  def normalize(value)
    value.to_s.downcase.gsub(/[^[:alnum:]\s]/, ' ').squish
  end
end
