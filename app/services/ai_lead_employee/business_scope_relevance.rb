# frozen_string_literal: true

class AiLeadEmployee::BusinessScopeRelevance
  STOP_WORDS = %w[
    a an and are can do does for from how i in is it my of on or our the this to we what with you your
    hii hiki jinsi kuhusu kwa la na ni unaweza ya yako
  ].freeze
  BUSINESS_DIRECTED_TOKENS = %w[
    business biashara company kampuni contact customer customers huduma inquiry inquiries integrate integration
    location offer offers open price pricing product products service services support team wateja your
  ].freeze

  def initialize(account:, message:, offer: nil)
    @account = account
    @message = message.to_s
    @offer = offer
  end

  def clearly_outside_scope?
    informational_question? && !business_directed? && !approved_scope_match?
  end

  private

  attr_reader :account, :message, :offer

  def informational_question?
    message.include?('?') || normalized_message.match?(
      /\A(?:can|could|do|does|how|is|are|what|when|where|which|who|why|je|jinsi|lini|nini|wapi)\b/
    )
  end

  def business_directed?
    normalized_message.split.intersect?(BUSINESS_DIRECTED_TOKENS)
  end

  def approved_scope_match?
    question_tokens = significant_tokens(message)
    return false if question_tokens.empty?

    approved_scope_texts.any? do |text|
      overlap = question_tokens & significant_tokens(text)
      overlap.size >= [2, question_tokens.size].min
    end
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
