# frozen_string_literal: true

class AiLeadEmployee::OfferQualificationService # rubocop:disable Metrics/ClassLength
  def initialize(conversation:, incoming_message: nil)
    @conversation = conversation
    @incoming_message = incoming_message
  end

  def perform
    conversation.with_lock('FOR NO KEY UPDATE') do
      resolve_offer!
      return selection_result unless offer

      offer.with_lock('FOR NO KEY UPDATE') do
        offer.enabled? ? qualification_mode_result : selection_result
      end
    end
  end

  private

  attr_reader :conversation, :incoming_message, :offer

  delegate :account, :contact, to: :conversation

  def qualification_mode_result
    return inactive_qualification_result unless offer.qualification_enabled?

    evaluate_selected_offer
  end

  def inactive_qualification_result
    AiLeadEmployee::QualificationService::Result.new(
      qualification: nil, qualification_mode: offer.qualification_mode, offer_id: offer.id,
      assessment: not_evaluated_assessment, next_step: offer.next_step, new_evidence: []
    )
  end

  def evaluate_selected_offer
    contact.with_lock do
      evidence = record_incoming_evidence!
      qualification = evaluate!

      AiLeadEmployee::QualificationService::Result.new(
        qualification: qualification, new_evidence: evidence,
        qualification_context: AiLeadEmployee::OfferDeliveryContext.capture(
          conversation: conversation, qualification: qualification, decision: @decision,
          next_question_key: next_question(qualification.evidence_snapshot)&.fetch('key')
        ),
        next_question: next_question(qualification.evidence_snapshot)&.fetch('prompt'),
        next_question_key: next_question(qualification.evidence_snapshot)&.fetch('key'),
        review_request_reason: qualification.unqualified? ? 'qualification_blocker' : nil,
        qualification_mode: offer.qualification_mode, offer_id: offer.id,
        assessment: qualification.assessment, next_step: offer.next_step
      )
    end
  end

  def resolve_offer!
    @offer = account.qualification_offers.find_by(id: conversation.offer_id)
    return if conversation.offer_id.present?

    candidates = account.qualification_offers.enabled_in_order.limit(2).to_a
    return unless candidates.one?

    @offer = candidates.first
    @offer.lock!('FOR NO KEY UPDATE')
    return @offer = nil unless @offer.enabled?

    conversation.update!(offer: offer)
  end

  def selection_result
    qualification = LeadQualification.new(account: account, contact: contact, quality: :unknown,
                                          evidence_snapshot: {}, missing_signals: ['offer'], reasons: ['Choose an Offer before qualification'])
    AiLeadEmployee::QualificationService::Result.new(
      qualification: qualification, new_evidence: [], next_question: 'Which Offer would you like to discuss?'
    )
  end

  def record_incoming_evidence!
    AiLeadEmployee::OfferEvidenceRecorder.new(conversation: conversation, offer: offer, incoming_message: incoming_message).perform
  end

  def evaluate!
    snapshot = evidence_snapshot
    quality, score, missing, rules, assessment = assess(snapshot)
    qualification = LeadQualification.find_or_initialize_by(account: account, contact: contact, offer: offer)
    qualification.assign_attributes(
      quality: quality, score: score, evidence_snapshot: snapshot, missing_signals: missing,
      reasons: reasons_for(snapshot, missing) + rules.reasons, configuration_version: offer.configuration_version,
      assessment: assessment, stale_at: nil, last_evaluated_at: Time.current, follow_up_state: follow_up_state(quality)
    )
    qualification.save!
    @decision = qualification.record_decision!
    qualification
  end

  def assess(snapshot)
    positive = positive_signals(snapshot)
    rules = AiLeadEmployee::OfferRules.new(offer: offer, snapshot: snapshot)
    assessment = assessment_for(snapshot, rules)
    missing = assessment.values.flat_map { |dimension| dimension.fetch('missing_fields') }.uniq
    weights = offer.configuration.fetch('score_weights', {})
    score = positive.sum { |signal| weights.fetch(signal, 0) } + rules.score_delta
    quality = rules.excluded? ? :unqualified : quality_for(snapshot, assessment, score)
    [quality, score, missing, rules, assessment]
  end

  def assessment_for(snapshot, rules)
    AiLeadEmployee::OfferRules::REQUIREMENT_DIMENSIONS.index_with do |dimension|
      dimension_requirements = rules.requirements.select { |rule| rule['dimension'] == dimension }
      question_fields = offer.questions.select { |question| question['required'] && question.fetch('purpose', 'fit') == dimension }.pluck('key')
      requirement_states = dimension_requirements.to_h { |rule| [rule['field'], rules.requirement_state(rule)] }
      question_states = question_fields.index_with { |field| evidence_state(snapshot[field]) }
      states = question_states.merge(requirement_states)
      dimension_assessment(states)
    end
  end

  def evidence_state(fact)
    return :missing unless fact && fact['polarity'] != 'unknown' && fact['asserted'] != false

    :met
  end

  def dimension_assessment(states) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    status = if states.empty?
               'not_required'
             elsif states.value?(:not_met)
               'not_met'
             elsif states.value?(:missing)
               'missing'
             else
               'met'
             end
    {
      'status' => status,
      'missing_fields' => states.filter_map { |field, state| field if state == :missing },
      'reasons' => states.filter_map { |field, state| "#{field.humanize} did not meet the configured requirement" if state == :not_met }
    }
  end

  def evidence_snapshot
    QualificationEvidence.current.where(account: account, contact: contact, offer: offer)
                         .where('observed_at >= ?', AiLeadEmployee::QualificationEvidenceSnapshot.fresh_after(account))
                         .order(:observed_at, :id).each_with_object({}) do |evidence, result|
      result[evidence.field_key] = evidence.value.merge(
        'evidence_id' => evidence.id, 'source' => evidence.source,
        'message_id' => evidence.message_id, 'conversation_id' => evidence.conversation_id,
        'observed_at' => evidence.observed_at.iso8601(6),
        'source_reference' => AiLeadEmployee::QualificationEvidenceSnapshot.source_reference_for(evidence)
      )
    end
  end

  def next_question(snapshot)
    offer.questions.find do |question|
      question['required'] && (!snapshot.key?(question['key']) || snapshot.dig(question['key'], 'asserted') == false ||
        snapshot.dig(question['key'], 'polarity') == 'unknown')
    end
  end

  def positive_signals(snapshot)
    snapshot.filter_map do |signal, fact|
      signal if fact['polarity'] == 'positive' && (signal != 'budget' || budget_assessment(fact) == :sufficient)
    end
  end

  def budget_assessment(fact)
    return :unknown unless valid_budget_fact?(fact)
    return :unknown if offer.budget_ranges.empty?

    matches = offer.budget_ranges.any? do |range|
      budget_in_range?(fact, range)
    end
    matches && fact['amount_minor'].positive? ? :sufficient : :insufficient
  end

  def valid_budget_fact?(fact)
    fact && fact['polarity'] == 'positive' && fact['currency'] == offer.currency && fact['amount_minor'].is_a?(Integer)
  end

  def budget_in_range?(fact, range)
    (!range['minimum_minor'] || fact['amount_minor'] >= range['minimum_minor']) &&
      (!range['maximum_minor'] || fact['amount_minor'] <= range['maximum_minor'])
  end

  def quality_for(snapshot, assessment, score)
    return :unqualified if assessment.dig('fit', 'status') == 'not_met'
    return :unknown if snapshot.empty? || snapshot.values.all? { |fact| fact['polarity'] == 'unknown' }

    quality_from_thresholds(assessment, score)
  end

  def quality_from_thresholds(assessment, score)
    thresholds = offer.configuration.fetch('score_thresholds')
    fit_complete = assessment.dig('fit', 'status').in?(%w[met not_required])
    return :highly_qualified if fit_complete && score >= thresholds.fetch('highly_qualified')
    return :qualified if fit_complete && score >= thresholds.fetch('qualified')

    :low_qualified
  end

  def reasons_for(snapshot, missing)
    snapshot.map { |signal, fact| "#{signal.humanize}: #{fact['value']} (#{fact['polarity']})" }.tap do |reasons|
      reasons << "Missing #{missing.map(&:humanize).join(', ')}" if missing.present?
    end
  end

  def follow_up_state(quality)
    return :human_review if quality == :highly_qualified
    return :nurture if quality.in?(%i[low_qualified qualified])

    :no_follow_up
  end

  def not_evaluated_assessment
    AiLeadEmployee::OfferRules::REQUIREMENT_DIMENSIONS.index_with do
      { 'status' => 'not_evaluated', 'missing_fields' => [], 'reasons' => [] }
    end
  end
end
