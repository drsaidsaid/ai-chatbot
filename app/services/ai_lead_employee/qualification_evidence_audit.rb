# frozen_string_literal: true

class AiLeadEmployee::QualificationEvidenceAudit
  def self.record!(contact:, conversation:, user:, signal:, value:)
    Audited::Audit.create!(
      auditable: contact,
      associated: contact.account,
      user: user,
      action: 'update',
      audited_changes: {
        'ai_lead_employee_action' => 'qualification_evidence_corrected',
        'conversation_id' => conversation&.id,
        'signal' => signal.to_s,
        'value' => value.to_s
      },
      version: Audited::Audit.where(auditable: contact).maximum(:version).to_i + 1,
      created_at: Time.current
    )
  end
end
