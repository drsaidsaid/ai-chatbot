# frozen_string_literal: true

require_relative 'language_detector'

class AiLeadEmployee::ConversationFollowUpPolicy
  ELIGIBLE_INTENTS = %i[business_question qualification_answer].freeze

  def initialize(classification:, qualification_result:, reply_kind: :conversation_reply)
    @classification = classification
    @qualification_result = qualification_result
    @reply_kind = reply_kind
  end

  def perform
    return unless eligible?

    question = qualification_result.next_question.to_s.strip
    return if question.blank? || AiLeadEmployee::LanguageDetector.detect(question) != classification.language

    question
  end

  private

  attr_reader :classification, :qualification_result, :reply_kind

  def eligible?
    reply_kind == :conversation_reply && qualification_result&.qualification_mode == 'enabled' &&
      classification&.intent.in?(ELIGIBLE_INTENTS)
  end
end
