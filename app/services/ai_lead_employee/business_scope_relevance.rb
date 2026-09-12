# frozen_string_literal: true

class AiLeadEmployee::BusinessScopeRelevance
  STOP_WORDS = %w[
    a an and are can do does for from how i in is it my of on or our the this to we what with you your
    hii hiki jinsi kuhusu kwa la na ni unaweza ya yako
  ].freeze
  EXTERNAL_HOW_TO_PATTERNS = [
    /\Ahow (?:do|can|could|should) i\b/,
    /\A(?:ninawezaje|nawezaje|jinsi gani ninaweza)\b/
  ].freeze

  def initialize(account:, message:, offer: nil)
    @account = account
    @message = message.to_s
    @offer = offer
  end

  def clearly_outside_scope?
    external_how_to? && !approved_scope_match?
  end

  private

  attr_reader :account, :message, :offer

  def external_how_to?
    EXTERNAL_HOW_TO_PATTERNS.any? { |pattern| normalized_message.match?(pattern) }
  end

  def approved_scope_match?
    question_tokens = significant_tokens(message)
    return false if question_tokens.empty?

    scope_texts.any? do |text|
      overlap = question_tokens & significant_tokens(text)
      overlap.size >= [2, question_tokens.size].min
    end
  end

  def scope_texts
    @scope_texts ||= offer_texts + knowledge_item_texts + knowledge_document_texts
  end

  def offer_texts
    offers = offer ? [offer] : account.qualification_offers.enabled_in_order.to_a
    offers.map { |candidate| [candidate.name, candidate.configuration].to_json }
  end

  def knowledge_item_texts
    account.knowledge_items.usable_by_ai_employee.filter_map do |item|
      [item.title, item.question, item.answer].join(' ') if item.verified_source_reference?
    end
  end

  def knowledge_document_texts
    account.knowledge_documents.eligible_for_ai_employee.filter_map do |document|
      [document.title, document.body].join(' ') if document.verified_source_reference?
    end
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
