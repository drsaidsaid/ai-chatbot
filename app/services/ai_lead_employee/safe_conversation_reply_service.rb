# frozen_string_literal: true

class AiLeadEmployee::SafeConversationReplyService
  KNOWLEDGE_GAP_REASONS = %w[no_approved_knowledge conflicting_knowledge source_unverified stale_knowledge].freeze
  CONVERSATION_REPLIES = {
    english: {
      language_question: 'Yes, I can continue in English or Swahili.',
      greeting: 'Hello. How can I help with this business today?',
      acknowledgment: 'Thank you.',
      qualification_answer: 'Thanks for those details.',
      scope_clarification: 'Are you asking about this business or one of its Offers?',
      generic_safe: 'Could you tell me what you need about this business?'
    },
    swahili: {
      language_question: 'Ndiyo, ninaweza kuendelea kwa Kiswahili au Kiingereza.',
      greeting: 'Habari. Ninaweza kusaidia kuhusu biashara hii leo?',
      acknowledgment: 'Asante.',
      qualification_answer: 'Asante kwa maelezo.',
      scope_clarification: 'Je, unauliza kuhusu biashara hii au mojawapo ya Ofa zake?',
      generic_safe: 'Unaweza kueleza unachohitaji kuhusu biashara hii?'
    }
  }.freeze

  def initialize(message:, qualification_result:, refusal_reason: nil, classification: nil)
    @message = message.to_s
    @refusal_reason = refusal_reason.to_s
    @qualification_result = qualification_result
    @classification = classification
  end

  def perform
    return unrelated_reply if classification.intent == :unrelated
    return personalized_strategy_reply if classification.intent == :personalized_strategy && knowledge_gap?
    return knowledge_gap_reply if knowledge_gap?
    return unless classification.safe_conversation?

    [conversation_reply, useful_next_question].compact_blank.join("\n\n")
  end

  private

  attr_reader :message, :refusal_reason, :qualification_result

  def classification
    @classification ||= AiLeadEmployee::ConversationIntentClassifier.new(message: message).perform
  end

  def knowledge_gap?
    KNOWLEDGE_GAP_REASONS.include?(refusal_reason)
  end

  def conversation_reply
    replies = CONVERSATION_REPLIES.fetch(swahili? ? :swahili : :english)
    replies.fetch(classification.intent, replies.fetch(:generic_safe))
  end

  def knowledge_gap_reply
    return 'Bado sina jibu lililoidhinishwa. Nimeweka swali lako kwa timu ili ilipitie.' if swahili?

    'I do not have an approved answer for that yet. I have recorded your question for the team to review.'
  end

  def personalized_strategy_reply
    return 'Siwezi kutengeneza mkakati binafsi kutoka taarifa ambazo hazijaidhinishwa. Nimeweka swali lako kwa timu ili ilipitie.' if swahili?

    'I cannot create a personalized strategy from unapproved information. I have recorded your question for the team to review.'
  end

  def unrelated_reply
    return 'Ninaweza kusaidia kwa maswali kuhusu biashara hii na Ofa zake.' if swahili?

    'I can help with questions about this business and its Offers.'
  end

  def useful_next_question
    return unless classification.intent.in?(%i[greeting qualification_answer personalized_strategy])
    return unless qualification_result&.qualification_mode == 'enabled'

    qualification_result.next_question
  end

  def swahili?
    classification.language == :swahili
  end
end
