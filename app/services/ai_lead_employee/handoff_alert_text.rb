# frozen_string_literal: true

class AiLeadEmployee::HandoffAlertText
  def initialize(account:, conversation:, qualification:)
    @account = account
    @conversation = conversation
    @qualification = qualification
  end

  def to_s
    [
      'Hot Lead handoff',
      "Conversation: #{conversation_url}",
      "Owner: #{conversation.assignee&.name || 'Unassigned'}",
      "Contact: #{conversation.contact.name} #{conversation.contact.phone_number} #{conversation.contact.email}".squish,
      *evidence_lines,
      "Qualification reasons: #{qualification.reasons.join('; ')}"
    ].join("\n")
  end

  private

  attr_reader :account, :conversation, :qualification

  def evidence_lines
    configured_labels = qualification.offer&.questions.to_a.index_by { |question| question['key'] }
    qualification.evidence_snapshot.filter_map do |key, evidence|
      value = evidence.to_h['value'].presence
      next if value.blank?

      label = configured_labels.dig(key, 'label').presence || key.to_s.humanize
      "#{label}: #{value}"
    end
  end

  def conversation_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    return path if base_url.blank?

    "#{base_url.delete_suffix('/')}#{path}"
  end
end
