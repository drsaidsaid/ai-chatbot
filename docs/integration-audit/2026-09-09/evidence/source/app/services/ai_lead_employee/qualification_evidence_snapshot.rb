# frozen_string_literal: true

class AiLeadEmployee::QualificationEvidenceSnapshot
  DEFAULT_FRESHNESS = 30.days

  def self.fresh_after(account)
    Time.current - freshness(account)
  end

  def self.freshness(account)
    days = account.settings&.dig('ai_lead_employee', 'qualification_evidence_fresh_for_days').presence
    return DEFAULT_FRESHNESS if days.blank?

    days.to_i.days
  end

  def self.source_reference_for(evidence)
    return human_source_reference(evidence) if evidence.human?

    {
      'type' => 'message',
      'evidence_id' => evidence.id,
      'message_id' => evidence.message_id,
      'conversation_id' => evidence.conversation_id
    }
  end

  def self.human_source_reference(evidence)
    {
      'type' => 'human_edit',
      'evidence_id' => evidence.id,
      'user_id' => evidence.user_id,
      'conversation_id' => evidence.conversation_id
    }
  end

  def initialize(account:, contact:)
    @account = account
    @contact = contact
  end

  def to_h
    QualificationEvidence.current
                         .where(account: account, contact: contact)
                         .where('observed_at >= ?', fresh_after)
                         .order(:created_at)
                         .each_with_object({}) do |evidence, result|
      result[evidence.signal] = evidence_payload(evidence)
    end
  end

  private

  attr_reader :account, :contact

  def evidence_payload(evidence)
    {
      'value' => evidence.value['value'],
      'source' => evidence.source,
      'evidence_id' => evidence.id,
      'conversation_id' => evidence.conversation_id,
      'message_id' => evidence.message_id,
      'observed_at' => evidence.observed_at.iso8601,
      'source_reference' => source_reference_for(evidence)
    }
  end

  def source_reference_for(evidence)
    self.class.source_reference_for(evidence)
  end

  def fresh_after
    self.class.fresh_after(account)
  end
end
