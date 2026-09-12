# frozen_string_literal: true

class AiLeadEmployee::KnowledgeAnswerService
  MATCH_STOPWORDS = %w[about are can does how is the this what when where which who why with your].freeze
  Result = Struct.new(:answer, :sources, :refusal_reason, keyword_init: true) do
    def answered?
      answer.present?
    end

    def refused?
      refusal_reason.present?
    end
  end

  APPROVED_ANSWER_PRIORITY = {
    'pricing' => 0,
    'refund' => 0,
    'guarantee' => 0,
    'eligibility' => 0,
    'policy' => 1,
    'offer' => 2,
    'faq' => 3,
    'objection' => 3,
    'supporting_document' => 4
  }.freeze

  def initialize(account:, question:, document_scope: nil, offer: nil, language: nil)
    @account = account
    @question = question.to_s
    @document_scope = document_scope
    @offer = offer
    @language = language&.to_s
  end

  def perform
    return unanswered_result('angry_question') if angry_question?
    return unanswered_result('sensitive_question') if high_risk_sensitive_question?

    item_result = approved_item_result
    return item_result if item_result.present?
    return unanswered_result('sensitive_question') if controlled_claim_question?

    document = matching_document
    return unanswered_result if document.blank?

    Result.new(answer: document_excerpt(document), sources: [document_source_payload(document)], refusal_reason: nil)
  end

  private

  attr_reader :account, :question, :document_scope, :offer, :language

  def approved_item_result
    matches = matching_items
    verified_matches = matches.select(&:verified_source_reference?)
    return unanswered_result(unverified_refusal_reason(matches)) if matches.present? && verified_matches.blank?
    return unanswered_result('conflicting_knowledge') if conflicting?(verified_matches)

    answer_result(verified_matches.first) if verified_matches.first.present?
  end

  def matching_items
    account.knowledge_items.usable_by_ai_employee
           .select { |item| eligible_item?(item) && matches?(item) }
           .sort_by { |item| [APPROVED_ANSWER_PRIORITY.fetch(item.source_kind), -match_score(item), item.created_at] }
  end

  def unverified_refusal_reason(matches)
    matches.any?(&:stale?) ? 'stale_knowledge' : 'source_unverified'
  end

  def conflicting?(matches)
    top_match = matches.first
    return false if top_match.blank?

    matches.any? do |item|
      item.id != top_match.id &&
        APPROVED_ANSWER_PRIORITY.fetch(item.source_kind) == APPROVED_ANSWER_PRIORITY.fetch(top_match.source_kind) &&
        match_score(item) == match_score(top_match) &&
        normalize(item.answer) != normalize(top_match.answer)
    end
  end

  def high_risk_sensitive_question?
    tokens(normalize(question)).intersect?(%w[liability contract legal lawsuit medical health])
  end

  def controlled_claim_question?
    tokens(normalize(question)).intersect?(%w[price pricing cost refund guarantee eligibility])
  end

  def angry_question?
    angry_tokens = %w[angry furious upset scam terrible unacceptable complaint]
    tokens(normalize(question)).intersect?(angry_tokens)
  end

  def matches?(item)
    normalized_question = normalize(question)
    normalized_item_question = normalize(item.question)
    return true if normalized_question.include?(normalized_item_question)
    return true if normalized_item_question.include?(normalized_question)

    question_tokens = tokens(normalized_question)
    item_tokens = tokens(normalized_item_question)
    overlap = (question_tokens & item_tokens).size
    overlap >= 2 && overlap.fdiv([question_tokens.size, item_tokens.size].min) >= 0.75
  end

  def eligible_item?(item)
    language_matches?(item.metadata['language']) && offer_scope_matches?(item.metadata['offer_ids'])
  end

  def language_matches?(configured_language)
    configured_language.blank? || language.blank? || normalized_language(configured_language) == normalized_language(language)
  end

  def normalized_language(value)
    { 'en' => 'english', 'sw' => 'swahili', 'kiswahili' => 'swahili' }.fetch(value.to_s.downcase, value.to_s.downcase)
  end

  def offer_scope_matches?(offer_ids)
    ids = Array(offer_ids).filter_map { |id| Integer(id, exception: false) }
    ids.empty? || (offer.present? && ids.include?(offer.id))
  end

  def match_score(item)
    (tokens(normalize(question)) & tokens(normalize(item.question))).size
  end

  def normalize(value)
    value.downcase.gsub(/[^a-z0-9\s]/, ' ').squish
  end

  def tokens(value)
    value.split.select { |token| token.length >= 3 && MATCH_STOPWORDS.exclude?(token) }
  end

  def source_payload(item)
    {
      id: item.id,
      title: item.title,
      source_kind: item.source_kind,
      type: 'knowledge_item',
      status: 'verified',
      approved_at: item.approved_at.iso8601,
      source_reference: item.source_reference,
      offer_id: offer&.id,
      offer_configuration_version: offer&.configuration_version
    }
  end

  def answer_result(item)
    Result.new(answer: item.answer, sources: [source_payload(item)], refusal_reason: nil)
  end

  def matching_document
    scope = document_scope.present? ? [document_scope] : account.knowledge_documents.published.where(used_by_ai_employee: true)
    scope.select { |document| document.verified_source_reference? && matches_document?(document) }
         .min_by { |document| [-document_score(document), document.updated_at] }
  end

  def matches_document?(document)
    return false unless document.published? && document.used_by_ai_employee?
    return false unless language_matches?(document.import_metadata['language'])
    return false unless document.general_question_access? || offer_scope_matches?(document.offer_ids)
    return false if document_expired?(document)

    (tokens(normalize(question)) & tokens(normalize([document.title, document.body].join(' ')))).size >= 2
  end

  def document_expired?(document)
    expires_at = document.import_metadata['expires_at']
    expires_at.present? && Time.zone.parse(expires_at.to_s) <= Time.current
  rescue ArgumentError, TypeError
    true
  end

  def document_score(document)
    (tokens(normalize(question)) & tokens(normalize([document.title, document.body].join(' ')))).size
  end

  def document_excerpt(document)
    document.body.to_s.split(/\n{2,}/).detect do |paragraph|
      tokens(normalize(question)).intersect?(tokens(normalize(paragraph)))
    end&.squish || document.body.to_s.squish.truncate(280)
  end

  def document_source_payload(document)
    {
      id: document.id,
      title: document.title,
      source_kind: 'document',
      type: 'knowledge_document',
      status: 'verified',
      approved_at: document.published_at.iso8601,
      source_reference: document.source_reference,
      offer_id: offer&.id,
      offer_configuration_version: offer&.configuration_version
    }
  end

  def unanswered_result(reason = 'no_approved_knowledge')
    Result.new(answer: nil, sources: [], refusal_reason: reason)
  end
end
