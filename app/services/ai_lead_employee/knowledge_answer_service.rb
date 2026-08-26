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
    item = matching_items.first
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

  def unanswered_result
    Result.new(answer: BOUNDARY_RESPONSE, sources: [], refusal_reason: 'no_approved_knowledge')
  end
end
