# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpit::EvidencePayload
  RECORD_LIMIT = 20

  def initialize(context)
    @context = context
  end

  def to_a
    payloads = records.map { |evidence| evidence_record_payload(evidence) }
    return payloads if payloads.any?

    snapshot_payload
  end

  private

  attr_reader :context

  def records
    @records ||=
      QualificationEvidence
      .where(account: context.account, contact: context.contact)
      .where(conversation_id: [context.conversation.id, nil])
      .includes(:message, :user)
      .order(observed_at: :desc, id: :desc)
      .limit(RECORD_LIMIT)
      .to_a
  end

  def evidence_record_payload(evidence)
    {
      id: evidence.id,
      signal: evidence.signal,
      value: context.stringify_evidence_value(evidence.value),
      source: evidence.source,
      source_message: evidence.message&.content,
      confidence: context.confidence_label,
      observed_at: evidence.observed_at&.iso8601,
      superseded: evidence.superseded_at.present?,
      user_name: evidence.user&.name
    }
  end

  def snapshot_payload
    context.evidence_snapshot.map do |signal, value|
      {
        id: "snapshot-#{signal}",
        signal: signal,
        value: context.stringify_evidence_value(value),
        source: 'qualification_snapshot',
        source_message: nil,
        confidence: context.confidence_label,
        observed_at: context.qualification&.last_evaluated_at&.iso8601,
        superseded: false
      }
    end
  end
end
