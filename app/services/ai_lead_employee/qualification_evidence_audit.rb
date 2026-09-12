# frozen_string_literal: true

class AiLeadEmployee::QualificationEvidenceAudit
  def initialize(contact:, conversation:, user:, offer_id: nil)
    @contact = contact
    @conversation = conversation
    @user = user
    @offer_id = offer_id
  end

  def record!(signal:, value:)
    Audited::Audit.create!(
      auditable: contact,
      associated: contact.account,
      user: user,
      action: 'update',
      audited_changes: {
        'ai_lead_employee_action' => 'qualification_evidence_corrected',
        'conversation_id' => conversation&.id,
        'offer_id' => offer_id,
        'signal' => signal.to_s,
        'value' => value.to_s
      },
      version: Audited::Audit.where(auditable: contact).maximum(:version).to_i + 1,
      created_at: Time.current
    )
  end

  private

  attr_reader :contact, :conversation, :user, :offer_id
end
