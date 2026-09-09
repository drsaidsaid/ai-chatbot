# frozen_string_literal: true

class AiLeadEmployee::PersistedQualificationEvidenceExtractor
  def initialize(account:, contact:, incoming_message:, evidence_snapshot:)
    @account = account
    @contact = contact
    @incoming_message = incoming_message
    @evidence_snapshot = evidence_snapshot.deep_dup
  end

  def perform
    lead_messages.flat_map { |message| extract_evidence_from_message!(message) }
  end

  private

  attr_reader :account, :contact, :incoming_message, :evidence_snapshot

  def extract_evidence_from_message!(message)
    extracted_values(message).filter_map do |signal, extracted_value|
      existing_evidence = evidence_snapshot[signal]
      next if existing_evidence&.fetch('source') == 'human'
      next if existing_evidence&.fetch('value') == extracted_value

      create_evidence!(message, signal, extracted_value)
    end
  end

  def create_evidence!(message, signal, extracted_value)
    QualificationEvidence.create!(
      account: account,
      contact: contact,
      conversation: message.conversation,
      message: message,
      signal: signal,
      source: :extracted,
      value: { 'value' => extracted_value },
      observed_at: message.created_at || Time.current
    ).tap do |new_evidence|
      AiLeadEmployee::QualificationService.supersede_current_evidence!(
        contact: contact,
        signal: signal,
        replacement: new_evidence
      )
      evidence_snapshot[signal] = { 'source' => new_evidence.source, 'value' => new_evidence.value['value'] }
    end
  end

  def extracted_values(message)
    AiLeadEmployee::QualificationEvidenceExtractor.new(message.content).evidence
  end

  def lead_messages
    messages = persisted_lead_messages.to_a
    messages << incoming_message if incoming_message.present? && !incoming_message.persisted?
    messages
  end

  def persisted_lead_messages
    conversation_ids = contact.conversations.where(account: account).select(:id)
    Message.where(account: account, conversation_id: conversation_ids, message_type: :incoming, private: false)
           .where.not(content: [nil, ''])
           .where('created_at >= ?', AiLeadEmployee::QualificationEvidenceSnapshot.fresh_after(account))
           .order(:created_at, :id)
  end
end
