# frozen_string_literal: true

class Api::V1::Accounts::LeadQualificationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :contact
  before_action :ensure_latest_conversation!

  def show
    qualification = contact.lead_qualification || qualification_result.qualification
    render json: qualification_payload(qualification)
  end

  def evidence
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
      )
    }
  end

  def ensure_latest_conversation!
    render json: { error: 'No conversation exists for this Lead' }, status: :not_found if latest_conversation.blank?
  end
end
