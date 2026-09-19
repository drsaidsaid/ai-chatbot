# frozen_string_literal: true

class AiLeadEmployee::ReviewAcknowledgment
  ELIGIBLE_REASONS = %w[
    no_approved_knowledge conflicting_knowledge sensitive_question angry_question
    source_unverified stale_knowledge provider_failed human_requested
  ].freeze

  COPY = {
    general: {
      english: 'I cannot give you a confirmed answer yet. I have recorded your question for the team to review.',
      swahili: 'Bado sina jibu lililothibitishwa. Nimeweka swali lako kwa timu ili ilipitie.'
    },
    complaint: {
      english: 'I am sorry you have had this experience. I have recorded your complaint for the team to review.',
      swahili: 'Pole kwa hali hii. Nimeweka malalamiko yako kwa timu ili iyapitie.'
    },
    refund_request: {
      english: 'I have recorded your refund request for the team to review.',
      swahili: 'Nimeweka ombi lako la kurejeshewa fedha kwa timu ili ilipitie.'
    },
    support_request: {
      english: 'I have recorded your support request for the team to review.',
      swahili: 'Nimeweka ombi lako la msaada kwa timu ili ilipitie.'
    },
    human_request: {
      english: 'I have recorded your request for human help.',
      swahili: 'Nimeweka ombi lako la msaada wa mtu kwa timu.'
    }
  }.freeze

  def initialize(reason:, language:, request_intent: nil)
    @reason = reason
    @language = language
    @request_intent = request_intent
  end

  def perform
    return unless ELIGIBLE_REASONS.include?(@reason.to_s)

    COPY.fetch(category).fetch(@language == :swahili ? :swahili : :english)
  end

  private

  def category
    return :human_request if @reason.to_s == 'human_requested'
    return :complaint if @reason.to_s == 'angry_question'
    return @request_intent if @reason.to_s == 'sensitive_question' && %i[refund_request support_request].include?(@request_intent)

    :general
  end
end
