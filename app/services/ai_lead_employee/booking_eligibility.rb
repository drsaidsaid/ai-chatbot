# frozen_string_literal: true

class AiLeadEmployee::BookingEligibility
  Result = Data.define(:eligible, :failure_code, :offer, :agreement_evidence, :prerequisite_snapshot) do
    def eligible? = eligible
  end

  def initialize(conversation:, qualification:, prerequisite_checker: nil, require_agreement: true)
    @conversation = conversation
    @qualification = qualification
    @prerequisite_checker = prerequisite_checker
    @require_agreement = require_agreement
  end

  def perform # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return failure('booking_offer_required') unless offer&.enabled?
    return failure('booking_not_available_for_offer') unless offer.next_step['kind'].in?(%w[sales_call appointment])
    return failure('offer_eligibility_not_met') unless qualification_eligible?

    agreement = current_agreement_evidence if @require_agreement
    return failure('lead_agreement_required') if @require_agreement && !explicit_agreement?(agreement)

    prerequisite = checker.perform
    return failure(prerequisite.failure_code, prerequisite.snapshot) unless prerequisite.met?

    Result.new(
      eligible: true,
      failure_code: nil,
      offer: offer,
      agreement_evidence: agreement,
      prerequisite_snapshot: prerequisite.snapshot
    )
  end

  private

  attr_reader :conversation, :qualification, :prerequisite_checker

  def offer
    @offer ||= conversation.offer
  end

  def qualification_eligible? # rubocop:disable Metrics/CyclomaticComplexity
    return true unless offer.qualification_enabled?
    return false unless qualification&.persisted? && qualification.offer_id == offer.id && qualification.stale_at.blank?
    return false unless qualification.configuration_version == offer.configuration_version

    %w[fit readiness action_eligibility].all? do |dimension|
      qualification.assessment.dig(dimension, 'status').in?(%w[met not_required])
    end
  end

  def agreement_field
    offer.next_step['agreement_field'].presence || (offer.next_step['kind'] == 'sales_call' ? 'sales_call_agreement' : 'appointment_agreement')
  end

  def current_agreement_evidence
    QualificationEvidence.current
                         .where(account: conversation.account, contact: conversation.contact, offer: offer, field_key: agreement_field)
                         .where('observed_at >= ?', AiLeadEmployee::QualificationEvidenceSnapshot.fresh_after(conversation.account))
                         .order(observed_at: :desc, id: :desc)
                         .first
  end

  def explicit_agreement?(evidence) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    evidence&.message&.incoming? && evidence.message.conversation_id == conversation.id &&
      evidence.message.sender_id == conversation.contact_id &&
      evidence.value&.fetch('typed_value', nil) == true && evidence.value['polarity'] == 'positive' &&
      evidence.value['offer_configuration_version'] == offer.configuration_version &&
      valid_proposal?(evidence.value, evidence.message_id)
  end

  def valid_proposal?(agreement, agreement_message_id) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    proposal = conversation.messages.outgoing.where(private: false).find_by(id: agreement['proposal_message_id'])
    metadata = proposal&.additional_attributes&.dig('ai_lead_employee', 'booking_proposal')
    immediately_preceding = conversation.messages.where(private: false).where('id < ?', agreement_message_id)
                                        .reorder(id: :desc).first
    proposal == immediately_preceding && metadata&.fetch('offer_id', nil) == offer.id &&
      metadata['offer_configuration_version'] == offer.configuration_version &&
      Time.zone.parse(metadata.fetch('starts_at')) == Time.zone.parse(agreement.fetch('agreed_starts_at'))
  rescue ArgumentError, KeyError, TypeError
    false
  end

  def checker
    prerequisite_checker || AiLeadEmployee::BookingPrerequisiteChecker.new(conversation: conversation, offer: offer)
  end

  def failure(code, prerequisite_snapshot = {})
    Result.new(
      eligible: false,
      failure_code: code,
      offer: offer,
      agreement_evidence: nil,
      prerequisite_snapshot: prerequisite_snapshot
    )
  end
end
