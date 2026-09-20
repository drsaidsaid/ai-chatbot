# frozen_string_literal: true

# Called inside the qualification owner's Conversation, Offer and Contact locks.
class AiLeadEmployee::OfferEvidenceRecorder
  def initialize(conversation:, offer:, incoming_message:, observations: nil)
    @conversation = conversation
    @offer = offer
    @incoming_message = incoming_message
    @provided_observations = observations
  end

  def perform
    return [] unless processable_message?
    return [] unless incoming_message.account_id == account.id && incoming_message.conversation_id == conversation.id

    observations.filter_map { |signal, value| record_observation!(signal, value) }
  end

  def answers_pending_question?
    processable_message? && observations.present?
  end

  private

  attr_reader :conversation, :offer, :incoming_message

  delegate :account, :contact, to: :conversation

  def processable_message?
    incoming_message&.persisted? && incoming_message.incoming? && !incoming_message.private?
  end

  def observations # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return @provided_observations if @provided_observations

    proposal = booking_proposal_observation
    return proposal if proposal.present?

    question = answered_question
    key = question&.fetch('key')
    builtin = QualificationQuestion::SIGNALS.key?(key&.to_sym)
    observations = AiLeadEmployee::QualificationEvidenceExtractor.new(incoming_message.content, answered_signal: builtin ? key : nil).observations
    add_typed_answer(observations, question, key) if observations.empty? && question && !builtin
    observations
  end

  def booking_proposal_observation # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    proposal_message = previous_message
    return unless proposal_message&.outgoing?

    proposal = proposal_message.additional_attributes&.dig('ai_lead_employee', 'booking_proposal')
    return unless proposal&.fetch('offer_id', nil) == offer.id &&
                  proposal['offer_configuration_version'] == offer.configuration_version

    answer = AiLeadEmployee::OfferTypedAnswer.new(
      question: { 'answer_type' => 'boolean' }, content: incoming_message.content, currency: offer.currency
    ).observation
    return unless answer&.fetch('typed_value', nil) == true

    field = offer.next_step['agreement_field'].presence ||
            (offer.next_step['kind'] == 'sales_call' ? 'sales_call_agreement' : 'appointment_agreement')
    { field => answer.merge('proposal_message_id' => proposal_message.id,
                            'agreed_starts_at' => Time.zone.parse(proposal.fetch('starts_at')).iso8601,
                            'offer_configuration_version' => offer.configuration_version) }
  rescue ArgumentError, KeyError
    nil
  end

  def add_typed_answer(observations, question, key)
    answer = AiLeadEmployee::OfferTypedAnswer.new(question: question, content: incoming_message.content, currency: offer.currency).observation
    answer = attach_agreed_time(answer, key)
    observations[key] = answer if answer
  end

  def attach_agreed_time(answer, key) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return answer unless answer&.fetch('typed_value', nil) == true

    agreement_field = offer.next_step['agreement_field'].presence ||
                      (offer.next_step['kind'] == 'sales_call' ? 'sales_call_agreement' : 'appointment_agreement')
    return answer unless key == agreement_field

    proposed = @answered_message&.additional_attributes&.dig('ai_lead_employee', 'booking_proposal', 'starts_at')
    return answer if proposed.blank?

    answer.merge('agreed_starts_at' => Time.zone.parse(proposed).iso8601)
  rescue ArgumentError
    answer
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
    previous = previous_message
    return unless previous&.outgoing?

    metadata = previous.additional_attributes.dig('ai_lead_employee', 'qualification') || {}
    return unless current_prompt_metadata?(metadata)

    matches = matching_questions(previous, metadata)
    @answered_message = previous if matches.one?
    matches.first if matches.one?
  end

  def previous_message
    @previous_message ||= conversation.messages.where(private: false).where('id < ?', incoming_message.id).reorder(id: :desc).first
  end

  def matching_questions(previous, metadata)
    offer.questions.select do |question|
      question['enabled'] != false && metadata['next_question_key'] == question['key'] &&
        previous.content.to_s.end_with?(metadata['next_question'].to_s)
    end
  end

  def current_prompt_metadata?(metadata)
    metadata['offer_id'] == offer.id &&
      metadata['configuration_version'] == offer.configuration_version &&
      metadata.fetch('selection_version', conversation.offer_selection_version) == conversation.offer_selection_version
  end
end
