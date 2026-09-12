# frozen_string_literal: true

# Called inside the qualification owner's Conversation, Offer and Contact locks.
class AiLeadEmployee::OfferEvidenceRecorder
  def initialize(conversation:, offer:, incoming_message:)
    @conversation = conversation
    @offer = offer
    @incoming_message = incoming_message
  end

  def perform
    return [] unless processable_message?
    return [] unless incoming_message.account_id == account.id && incoming_message.conversation_id == conversation.id

    observations.filter_map { |signal, value| record_observation!(signal, value) }
  end

  def answers_pending_question?
    processable_message? && answered_question.present?
  end

  private

  attr_reader :conversation, :offer, :incoming_message

  delegate :account, :contact, to: :conversation

  def processable_message?
    incoming_message&.persisted? && incoming_message.incoming? && !incoming_message.private?
  end

  def observations
    question = answered_question
    key = question&.fetch('key')
    builtin = QualificationQuestion::SIGNALS.key?(key&.to_sym)
    observations = AiLeadEmployee::QualificationEvidenceExtractor.new(incoming_message.content, answered_signal: builtin ? key : nil).observations
    add_typed_answer(observations, question, key) if observations.empty? && question && !builtin
    observations
  end

  def add_typed_answer(observations, question, key)
    answer = AiLeadEmployee::OfferTypedAnswer.new(question: question, content: incoming_message.content, currency: offer.currency).observation
    observations[key] = answer if answer
  end

  def record_observation!(signal, value)
    value = value_with_definition(signal, value)
    scope = QualificationEvidence.where(account: account, contact: contact, offer: offer, field_key: signal)
    return if scope.current.human.exists? || scope.exists?(message: incoming_message, value: value)
    return if scope.current.exists?(['observed_at > ?', incoming_message.created_at])

    evidence = create_observation!(scope, signal, value)
    scope.current.where.not(id: evidence.id).find_each do |previous|
      previous.update!(superseded_at: Time.current, superseded_by: evidence)
    end
    evidence
  end

  def value_with_definition(signal, value)
    definition = offer.configuration.fetch('questions').find { |candidate| candidate['key'] == signal }
    return value unless definition

    value.merge('field_definition' => AiLeadEmployee::OfferConfigurationWriter.field_definition(definition, offer.currency))
  end

  def create_observation!(scope, signal, value)
    scope.create!(signal: QualificationQuestion::SIGNALS.key?(signal.to_sym) ? signal : nil,
                  conversation: conversation, message: incoming_message, source: :extracted,
                  value: value, observed_at: incoming_message.created_at)
  end

  def answered_question
    previous = conversation.messages.where(private: false).where('id < ?', incoming_message.id).reorder(id: :desc).first
    return unless previous&.outgoing?

    metadata = previous.additional_attributes.dig('ai_lead_employee', 'qualification') || {}
    return unless metadata['offer_id'] == offer.id && metadata['configuration_version'] == offer.configuration_version

    matches = matching_questions(previous, metadata)
    matches.first if matches.one?
  end

  def matching_questions(previous, metadata)
    offer.questions.select do |question|
      previous.content.to_s.end_with?(question['prompt']) && metadata['next_question'] == question['prompt'] &&
        metadata['next_question_key'] == question['key']
    end
  end
end
