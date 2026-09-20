# frozen_string_literal: true

# Read-only selection and scope shared by Lead and Conversation projections.
class AiLeadEmployee::OfferQualificationReadContext
  attr_reader :offer

  def initialize(account:, user:, offer_id: nil)
    @account = account
    @access = AiLeadEmployee::AccessScope.new(account: account, user: user)
    @offer = account.qualification_offers.find(offer_id) if offer_id.present?
  end

  def offers_configured?
    offers.any?
  end

  def selection_required?
    offers_configured? && offer.nil?
  end

  def qualifications
    return @access.qualifications.none if selection_required?

    @access.qualifications.where(offer_id: offer&.id)
  end

  def qualification(contact)
    qualifications.find_by(contact_id: contact.id)
  end

  def legacy_qualifications
    @access.qualifications.where(offer_id: nil)
  end

  def evidence
    return @access.related(QualificationEvidence).none if selection_required?

    @access.related(QualificationEvidence).where(offer_id: offer&.id)
  end

  def related_to_qualification(scope)
    related = @access.related(scope)
    return related.none if selection_required?
    return related unless offers_configured?

    related.where(lead_qualification_id: LeadQualification.where(account: @account, offer: offer).select(:id))
  end

  def metadata
    {
      offer_id: offer&.id,
      qualification_mode: offer&.qualification_mode,
      next_step: offer&.next_step,
      selection_required: selection_required?,
      current_configuration_version: offer&.configuration_version,
      fields: field_definitions,
      offers: offers
    }
  end

  def evidence_records(contact)
    records = evidence.where(contact: contact).order(observed_at: :desc, id: :desc).limit(20).to_a
    source_ids = records.filter_map(&:conversation_id).uniq
    @source_display_ids = @access.conversations.where(id: source_ids).pluck(:id, :display_id).to_h
    records
  end

  def evidence_source_path(evidence)
    display_id = @source_display_ids&.fetch(evidence.conversation_id, nil)
    return unless display_id

    path = "/app/accounts/#{@account.id}/conversations/#{display_id}"
    evidence.message_id ? "#{path}?messageId=#{evidence.message_id}" : path
  end

  def qualification_metadata(qualification)
    metadata.merge(configuration_version: qualification&.persisted? ? qualification.configuration_version : nil,
                   stale_at: qualification&.stale_at&.iso8601,
                   assessment: assessment_for(qualification))
  end

  def assessment_for(qualification)
    return qualification.assessment if qualification&.persisted?

    status = offer && !offer.qualification_enabled? ? 'not_evaluated' : 'not_assessed'
    AiLeadEmployee::OfferRules::REQUIREMENT_DIMENSIONS.index_with do
      { 'status' => status, 'missing_fields' => [], 'reasons' => [] }
    end
  end

  def next_question(qualification)
    return if qualification_question_suppressed?
    return unless offers_configured?

    snapshot = qualification&.evidence_snapshot || {}
    return next_offer_question(snapshot) if offer
  end

  def legacy_payload(qualification)
    return unless offers_configured? && qualification

    {
      scope: 'legacy_unscoped', label: 'Legacy qualification — not assigned to an Offer',
      quality: qualification.quality, score: qualification.score, reasons: qualification.reasons,
      evidence: qualification.evidence_snapshot, configuration_version: qualification.configuration_version,
      last_evaluated_at: qualification.last_evaluated_at
    }
  end

  private

  def qualification_question_suppressed?
    selection_required? || (offer && (!offer.enabled? || !offer.qualification_enabled?))
  end

  def next_offer_question(snapshot) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    rules = AiLeadEmployee::OfferRules.new(offer: offer, snapshot: snapshot)
    direct = offer.questions.find do |question|
      question['required'] && (!snapshot.key?(question['key']) || snapshot.dig(question['key'], 'asserted') == false ||
        snapshot.dig(question['key'], 'polarity') == 'unknown') && rules.group_fields(question.fetch('purpose', 'fit')).exclude?(question['key'])
    end
    return direct.fetch('prompt') if direct

    missing = rules.requirement_groups.flat_map { |group| rules.group_assessment(group)[:missing_fields] }.uniq
    offer.questions.find { |question| missing.include?(question['key']) }&.fetch('prompt')
  end

  def field_definitions
    return [] unless offer

    offer.configuration.fetch('questions', []).map do |question|
      question.slice('key', 'meaning', 'answer_type', 'options', 'period', 'enabled', 'required', 'purpose', 'prompt')
    end
  end

  def offers
    @offers ||= @account.qualification_offers.order(:position, :id).map do |candidate|
      { id: candidate.id, name: candidate.name, currency: candidate.currency,
        enabled: candidate.enabled, qualification_mode: candidate.qualification_mode,
        next_step: candidate.next_step, configuration_version: candidate.configuration_version }
    end
  end
end
