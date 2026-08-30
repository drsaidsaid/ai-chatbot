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
      "Contact: #{conversation.contact.name} #{conversation.contact.phone_number} #{conversation.contact.email}".squish,
      "Business type: #{value_for('business_type')}",
      "Problem: #{value_for('problem')}",
      "Lead volume: #{value_for('lead_volume')}",
      "Urgency: #{value_for('urgency')}",
      "Budget signal: #{value_for('budget')}",
      "Decision authority: #{value_for('decision_authority')}",
      "Qualification reasons: #{qualification.reasons.join('; ')}"
    ].join("\n")
  end

  private

  attr_reader :account, :conversation, :qualification

  def value_for(signal)
    qualification.evidence_snapshot.dig(signal, 'value').presence || 'Not provided'
  end

  def conversation_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    return path if base_url.blank?

    "#{base_url.delete_suffix('/')}#{path}"
  end
end
