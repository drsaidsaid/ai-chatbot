# frozen_string_literal: true

class AiLeadEmployee::SafeConversationReplyService
  KNOWLEDGE_GAP_REASON = 'no_approved_knowledge'

  SWAHILI_QUESTION_TRANSLATIONS = {
    'What is your name?' => 'Jina lako ni nani?',
    'What type of business do you run?' => 'Unaendesha biashara ya aina gani?',
    'What problem are you trying to solve right now?' =>
      'Unajaribu kutatua changamoto gani kwa sasa?',
    'How many leads or inquiries do you handle each month?' =>
      'Unapata leads au maulizo mangapi kwa mwezi?',
    'How soon do you want this solved?' => 'Ungependa hili litatuliwe ndani ya muda gani?',
    'What budget range have you set aside for this?' => 'Umetenga bajeti ya kiwango gani kwa hili?',
    'Are you the person who decides on this purchase?' =>
      'Je, wewe ndiye unayefanya uamuzi wa kununua?',
    'What is the best email or phone number for follow-up?' =>
      'Ni barua pepe au namba gani bora kwa ajili ya kufuatilia?'
  }.freeze

  def initialize(message:, refusal_reason:, qualification_result:)
    @message = message.to_s
    @refusal_reason = refusal_reason.to_s
    @qualification_result = qualification_result
  end

  def perform
    return if refusal_reason != KNOWLEDGE_GAP_REASON
    return if classification.risky?

    [base_reply, localized_next_question].compact_blank.join("\n\n")
  end

  private

  attr_reader :message, :refusal_reason, :qualification_result

  def classification
    @classification ||= AiLeadEmployee::ConversationIntentClassifier.new(message: message).perform
  end

  def base_reply
    return localized_language_reply if classification.intent == :language_question
    return localized_greeting_reply if classification.intent == :greeting

    swahili? ? swahili_knowledge_gap_reply : english_knowledge_gap_reply
  end

  def localized_language_reply
    return 'Ndiyo, ninaweza kuendelea kwa Kiswahili au Kiingereza.' if swahili?

    'Yes, I can continue in English or Swahili.'
  end

  def localized_greeting_reply
    return 'Habari. Ninaweza kusaidia kukusanya taarifa zako kwa Online Profits.' if swahili?

    'Hello. I can help qualify your request for Online Profits.'
  end

  def english_knowledge_gap_reply
    [
      'I do not have an approved answer for that yet, so I will flag it for review.',
      'I can still collect a few details so the team can help you properly.'
    ].join(' ')
  end

  def swahili_knowledge_gap_reply
    [
      'Bado sina jibu lililoidhinishwa kwa swali hilo, kwa hiyo nitalipeleka kwa ukaguzi.',
      'Naweza kuendelea kukusanya taarifa chache ili timu ikusaidie vizuri.'
    ].join(' ')
  end

  def localized_next_question
    question = qualification_result&.next_question
    return if question.blank?
    return SWAHILI_QUESTION_TRANSLATIONS.fetch(question, question) if swahili?

    question
  end

  def swahili?
    classification.language == :swahili
  end
end
