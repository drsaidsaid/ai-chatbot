# frozen_string_literal: true

class Api::V1::Accounts::LeadQualificationsController < Api::V1::Accounts::BaseController
  before_action :contact
  before_action :ensure_latest_conversation!

  def show
    qualification = contact.lead_qualification || qualification_result.qualification
    authorize qualification, :show?

    render json: qualification_payload(qualification)
  end

  def evidence
    authorize lead_qualification_for_evidence, :evidence?

    evidence = AiLeadEmployee::QualificationService.record_human_evidence!(
      contact: contact,
      conversation: latest_conversation,
      user: Current.user,
      signal: params.require(:signal),
      value: params.require(:value)
    )
    qualification = AiLeadEmployee::QualificationService.new(conversation: latest_conversation).perform.qualification

    render json: qualification_payload(qualification).merge(evidence_id: evidence.id)
  end

  private

  def contact
    @contact ||= current_account.contacts.find(params[:id])
  end

  def latest_conversation
    @latest_conversation ||= contact.conversations.where(account: current_account).order(last_activity_at: :desc, id: :desc).first
  end

  def qualification_result
    @qualification_result ||= AiLeadEmployee::QualificationService.new(conversation: latest_conversation).perform
  end

  def lead_qualification_for_evidence
    contact.lead_qualification || LeadQualification.new(account: current_account, contact: contact)
  end

  def qualification_payload(qualification)
    {
      id: qualification.id,
      contact_id: contact.id,
      quality: qualification.quality,
      follow_up_state: qualification.follow_up_state,
      score: qualification.score,
      reasons: qualification.reasons,
      missing_signals: qualification.missing_signals,
      evidence: qualification.evidence_snapshot,
      configuration_version: qualification.configuration_version,
      next_question: AiLeadEmployee::QualificationService.next_question_for(
        account: current_account,
        evidence_snapshot: qualification.evidence_snapshot
      ),
      evidence_records: evidence_records_payload,
      handoffs: handoffs_payload(qualification),
      follow_ups: qualification.lead_follow_ups.order(created_at: :desc).limit(10).map { |follow_up| follow_up_payload(follow_up) },
      follow_up_opted_out: LeadFollowUpOptOut.exists?(account: current_account, contact: contact)
    }
  end

  def evidence_records_payload
    QualificationEvidence.where(account: current_account, contact: contact)
                         .order(observed_at: :desc, id: :desc)
                         .limit(20)
                         .map { |evidence| evidence_payload(evidence) }
  end

  def evidence_payload(evidence)
    {
      id: evidence.id,
      signal: evidence.signal,
      value: evidence.value['value'],
      source: evidence.source,
      source_reference: AiLeadEmployee::QualificationEvidenceSnapshot.source_reference_for(evidence),
      observed_at: evidence.observed_at&.iso8601,
      superseded: evidence.superseded_at.present?
    }
  end

  def handoffs_payload(qualification)
    qualification.lead_handoffs.order(created_at: :desc).limit(5).map do |handoff|
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
