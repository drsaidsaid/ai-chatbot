# frozen_string_literal: true

class AiLeadEmployee::LeadNameCaptureService
  NAME_PREFIX = /\A(?:my name is|i am|i'm|naitwa|jina langu ni|mimi ni)\s+/i
  GENERIC_ANSWERS = %w[hi hello hey habari mambo yes no ndio okay ok sawa].freeze
  MAX_NAME_LENGTH = 80
  MAX_NAME_WORDS = 6

  def initialize(account:, contact:, conversation:, incoming_message:, name_prompt:)
    @account = account
    @contact = contact
    @conversation = conversation
    @incoming_message = incoming_message
    @name_prompt = name_prompt
  end

  def perform
    from_contact_profile = meaningful_contact_name?
    candidate = from_contact_profile ? contact.name.to_s.squish : name_from_answer
    return if candidate.blank?

    contact.with_lock do
      contact.update!(name: candidate) unless contact.name == candidate
      persist_evidence!(candidate, from_contact_profile: from_contact_profile)
    end
  end

  private

  attr_reader :account, :contact, :conversation, :incoming_message, :name_prompt

  def meaningful_contact_name?
    name = contact.name.to_s.squish
    return false if name.blank? || phone_number?(name)

    normalized_phone = contact.phone_number.to_s.gsub(/\D/, '')
    normalized_name = name.gsub(/\D/, '')
    normalized_phone.blank? || normalized_name != normalized_phone
  end

  def name_from_answer
    return unless name_question_asked?

    candidate = incoming_message.content.to_s.squish.sub(NAME_PREFIX, '').strip
    return unless valid_name?(candidate)

    candidate
  end

  def name_question_asked?
    return false if incoming_message.blank? || name_prompt.blank?

    previous_outgoing_message&.content.to_s.include?(name_prompt)
  end

  def previous_outgoing_message
    @previous_outgoing_message ||= conversation.messages
                                               .outgoing
                                               .where(private: false)
                                               .where('id < ?', incoming_message.id)
                                               .order(id: :desc)
                                               .first
  end

  def valid_name?(candidate)
    return false if candidate.blank? || candidate.length > MAX_NAME_LENGTH
    return false if candidate.split.size > MAX_NAME_WORDS
    return false if GENERIC_ANSWERS.include?(candidate.downcase) || phone_number?(candidate)

    candidate.match?(/\A[\p{L}][\p{L}\p{M}\s.'-]*\z/)
  end

  def phone_number?(value)
    value.match?(/\A\+?[\d\s().-]+\z/)
  end

  def persist_evidence!(candidate, from_contact_profile:)
    existing = current_name_evidence
    return existing if existing&.value&.dig('value') == candidate

    evidence = QualificationEvidence.create!(
      account: account,
      contact: contact,
      conversation: conversation,
      message: from_contact_profile ? nil : incoming_message,
      signal: :name,
      source: :extracted,
      value: { 'value' => candidate },
      observed_at: incoming_message&.created_at || Time.current
    )
    AiLeadEmployee::QualificationService.supersede_current_evidence!(contact: contact, signal: :name, replacement: evidence)
    evidence
  end

  def current_name_evidence
    QualificationEvidence.current
                         .where(account: account, contact: contact, signal: :name)
                         .where('observed_at >= ?', AiLeadEmployee::QualificationEvidenceSnapshot.fresh_after(account))
                         .order(created_at: :desc)
                         .first
  end
end
