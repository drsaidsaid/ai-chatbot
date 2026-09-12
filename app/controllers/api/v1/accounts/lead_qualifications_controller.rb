# frozen_string_literal: true

class Api::V1::Accounts::LeadQualificationsController < Api::V1::Accounts::BaseController
  before_action :contact
  before_action :ensure_latest_conversation!

  def show
    qualification = read_context.qualification(contact)
    authorize qualification || empty_qualification(read_context.offer), :show?

    render json: qualification_payload(qualification)
  end

  def evidence
    return record_offer_evidence if params[:offer_id].present? || current_account.qualification_offers.exists?

    authorize lead_qualification_for_evidence, :evidence?

    evidence = record_legacy_evidence
    AiLeadEmployee::QualificationService.new(conversation: latest_conversation).perform

    render json: qualification_payload(access.qualification(contact) || empty_qualification).merge(evidence_id: evidence.id)
  end

  private

  def record_offer_evidence
    selected_offer = current_account.qualification_offers.find(params.require(:offer_id))
    evidence = write_offer_evidence(selected_offer)
    qualification = access.qualifications.find_by(contact: contact, offer: selected_offer)
    render json: qualification_payload(qualification).merge(evidence_id: evidence.id)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def write_offer_evidence(offer)
    AiLeadEmployee::OfferHumanEvidenceWriter.new(
      conversation: evidence_conversation, offer: offer, user: Current.user,
      field_key: params[:field_key].presence || params.require(:signal), value: params.require(:value)
    ).perform
  end

  def empty_qualification(offer = nil)
    LeadQualification.new(account: current_account, contact: contact, offer: offer)
  end

  def evidence_conversation
    access.conversations.where(contact: contact).find_by!(display_id: params.require(:conversation_id))
  end

  def record_legacy_evidence
    AiLeadEmployee::QualificationService.record_human_evidence!(
      contact: contact, conversation: latest_conversation, user: Current.user,
      signal: params.require(:signal), value: params.require(:value)
    )
  end

  def read_context
    @read_context ||= AiLeadEmployee::OfferQualificationReadContext.new(account: current_account, user: Current.user, offer_id: params[:offer_id])
  end

  def access
    AiLeadEmployee::AccessScope.new(account: current_account, user: Current.user)
  end

  def contact
    @contact ||= policy_scope(current_account.contacts).find(params[:id])
  end

  def latest_conversation
    @latest_conversation ||= access.conversations.where(contact: contact).order(last_activity_at: :desc, id: :desc).first
  end

  def lead_qualification_for_evidence
    contact.lead_qualification || LeadQualification.new(account: current_account, contact: contact)
  end

  def qualification_payload(qualification) # rubocop:disable Metrics/CyclomaticComplexity
    {
      id: qualification&.id,
      contact_id: contact.id,
      offer_id: qualification&.offer_id || read_context.offer&.id,
      stale_at: qualification&.stale_at&.iso8601,
      quality: qualification&.quality,
      follow_up_state: qualification&.follow_up_state,
      score: qualification&.score,
      reasons: qualification&.reasons || [],
      missing_signals: qualification&.missing_signals || [],
      evidence: qualification&.evidence_snapshot || {},
      assessment: read_context.assessment_for(qualification),
      configuration_version: qualification&.configuration_version
    }.merge(qualification_context_payload(qualification))
  end

  def qualification_context_payload(qualification)
    {
      next_question: read_context.next_question(qualification),
      legacy_qualification: read_context.legacy_payload(read_context.legacy_qualifications.find_by(contact: contact)),
      evidence_records: evidence_records_payload(qualification),
      handoffs: handoffs_payload(qualification),
      follow_ups: follow_ups_payload(qualification),
      follow_up_opted_out: LeadFollowUpOptOut.exists?(account: current_account, contact: contact)
    }.merge(read_context.qualification_metadata(qualification))
  end

  def evidence_records_payload(_qualification)
    read_context.evidence_records(contact).map { |evidence| evidence_payload(evidence) }
  end

  def evidence_payload(evidence)
    {
      id: evidence.id,
      signal: evidence.signal,
      field_key: evidence.field_key,
      offer_id: evidence.offer_id,
      normalized_value: evidence.value,
      value: evidence.value['value'],
      source: evidence.source,
      source_reference: AiLeadEmployee::QualificationEvidenceSnapshot.source_reference_for(evidence),
      source_path: read_context.evidence_source_path(evidence),
      observed_at: evidence.observed_at&.iso8601,
      superseded: evidence.superseded_at.present?
    }
  end

  def handoffs_payload(qualification)
    return [] unless qualification

    access.related(qualification.lead_handoffs).order(created_at: :desc).limit(5).map do |handoff|
      {
        id: handoff.id,
        status: handoff.status,
        alert_type: handoff.alert_type,
        assignee_id: handoff.assignee_id,
        handed_off_at: handoff.handed_off_at&.iso8601,
        alert_recipients: handoff.alert_recipients,
        alert_deliveries: handoff.alert_deliveries
      }
    end
  end

  def follow_ups_payload(qualification)
    return [] unless qualification

    access.related(qualification.lead_follow_ups).order(created_at: :desc).limit(10).map { |follow_up| follow_up_payload(follow_up) }
  end

  def follow_up_payload(follow_up)
    follow_up.as_json(
      only: [
        :id, :status, :stage, :attempt_number, :question_text, :content, :scheduled_at, :sent_at,
        :cancelled_at, :failed_at, :cancellation_reason, :failure_reason
      ]
    )
  end

  def ensure_latest_conversation!
    render json: { error: 'No conversation exists for this Lead' }, status: :not_found if latest_conversation.blank?
  end
end
