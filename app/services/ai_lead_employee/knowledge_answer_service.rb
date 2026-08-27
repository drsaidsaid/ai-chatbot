# frozen_string_literal: true

class AiLeadEmployee::KnowledgeAnswerService
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

  def initialize(account:, question:, document_scope: nil)
    @account = account
    @question = question.to_s
    @document_scope = document_scope
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

  attr_reader :account, :question, :document_scope

  def approved_item_result
    matches = matching_items
    verified_matches = matches.select(&:verified_source_reference?)
    return unanswered_result(unverified_refusal_reason(matches)) if matches.present? && verified_matches.blank?
    return unanswered_result('conflicting_knowledge') if conflicting?(verified_matches)

    answer_result(verified_matches.first) if verified_matches.first.present?
  end

  def matching_items
    account.knowledge_items.usable_by_ai_employee
           .select { |item| matches?(item) }
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

    (tokens(normalized_question) & tokens(normalized_item_question)).size >= 2
  end

  def match_score(item)
    (tokens(normalize(question)) & tokens(normalize(item.question))).size
  end

  def normalize(value)
    value.downcase.gsub(/[^a-z0-9\s]/, ' ').squish
  end

  def tokens(value)
    value.split.select { |token| token.length >= 3 }
  end

  def source_payload(item)
    {
      id: item.id,
      title: item.title,
      source_kind: item.source_kind,
      type: 'knowledge_item',
      status: 'verified',
      approved_at: item.approved_at.iso8601,
      source_reference: item.source_reference
    }
  end

  def answer_result(item)
    Result.new(answer: item.answer, sources: [source_payload(item)], refusal_reason: nil)
  end

  def matching_document
    scope = document_scope.present? ? [document_scope] : account.knowledge_documents.eligible_for_ai_employee
    scope.select { |document| document.verified_source_reference? && matches_document?(document) }
         .min_by { |document| [-document_score(document), document.updated_at] }
  end

  def matches_document?(document)
    return false unless document.published? && document.used_by_ai_employee? && document.general_question_access?

    (tokens(normalize(question)) & tokens(normalize([document.title, document.body].join(' ')))).size >= 2
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
      source_reference: document.source_reference
    }
  end

  def unanswered_result(reason = 'no_approved_knowledge')
    Result.new(answer: nil, sources: [], refusal_reason: reason)
  end
end
