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

  SOURCE_PRIORITY = {
    'faq' => 0,
    'offer' => 1,
    'pricing' => 2,
    'supporting_document' => 3
  }.freeze

  BOUNDARY_RESPONSE = 'I can only answer questions covered by our approved business information. Please send a business or offer question in text.'

  def initialize(account:, question:)
    @account = account
    @question = question.to_s
  end

  def perform
    return unanswered_result('angry_question') if angry_question?
    return unanswered_result('sensitive_question') if sensitive_question?

    matches = matching_items
    return unanswered_result if matches.blank?
    return unanswered_result('conflicting_knowledge') if conflicting?(matches)

    item = matches.first
    return unanswered_result if item.blank?

    Result.new(
      answer: item.answer,
      sources: [source_payload(item)],
      refusal_reason: nil
    )
  end

  private

  attr_reader :account, :question

  def matching_items
    account.knowledge_items.usable_by_ai_employee
           .select { |item| matches?(item) }
           .sort_by { |item| [SOURCE_PRIORITY.fetch(item.source_kind), -match_score(item), item.created_at] }
  end

  def conflicting?(matches)
    top_match = matches.first
    matches.any? do |item|
      item.id != top_match.id &&
        SOURCE_PRIORITY.fetch(item.source_kind) == SOURCE_PRIORITY.fetch(top_match.source_kind) &&
        match_score(item) == match_score(top_match) &&
        normalize(item.answer) != normalize(top_match.answer)
    end
  end

  def sensitive_question?
    sensitive_tokens = %w[legal lawsuit contract medical health refund guarantee liability]
    tokens(normalize(question)).intersect?(sensitive_tokens)
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
      source_kind: item.source_kind
    }
  end

  def unanswered_result(reason = 'no_approved_knowledge')
    Result.new(answer: BOUNDARY_RESPONSE, sources: [], refusal_reason: reason)
  end
end
