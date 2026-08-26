# frozen_string_literal: true

class AiLeadEmployee::HighlyQualifiedHandoffService
  ALERT_TYPE = 'highly_qualified_sales_handoff'
  DEFAULT_UNQUALIFIED_HUMAN_REQUEST_EXPLANATION =
    'I need to confirm a few details first so the right Human Operator can help you.'

  Result = Struct.new(:handoff, :created, :assignee, keyword_init: true)

  def initialize(conversation:, qualification:)
    @conversation = conversation
    @qualification = qualification
    @account = conversation.account
  end

  def perform
    return Result.new unless automatic_handoff_allowed?

    handoff, created = find_or_create_handoff!
    return Result.new(handoff: handoff, created: false, assignee: handoff.assignee) unless created

    assign_operator!(handoff)
    deliver_alerts!(handoff)
    Result.new(handoff: handoff.reload, created: true, assignee: handoff.assignee)
  rescue ActiveRecord::RecordNotUnique
    handoff = account.lead_handoffs.find_by!(
      conversation: conversation,
      lead_qualification: qualification,
      alert_type: ALERT_TYPE
    )
    Result.new(handoff: handoff, created: false, assignee: handoff.assignee)
  end

  def self.unqualified_human_request_explanation(account)
    account.settings&.dig('ai_lead_employee', 'unqualified_human_request_explanation').presence ||
      DEFAULT_UNQUALIFIED_HUMAN_REQUEST_EXPLANATION
  end

  private

  attr_reader :account, :conversation, :qualification

  def automatic_handoff_allowed?
    qualification&.highly_qualified? &&
      (AiLeadEmployee::QualificationService::REQUIRED_HIGHLY_QUALIFIED_SIGNALS - qualification.evidence_snapshot.keys).empty?
  end

  def find_or_create_handoff!
    handoff = nil
    created = false

    LeadHandoff.transaction(requires_new: true) do
      handoff = account.lead_handoffs.find_or_initialize_by(
        conversation: conversation,
        lead_qualification: qualification,
        alert_type: ALERT_TYPE
      )
      created = handoff.new_record?
      handoff.assign_attributes(new_handoff_attributes) if created
      handoff.save!
    end

    [handoff, created]
  end

  def new_handoff_attributes
    {
      contact: conversation.contact,
      assignee: configured_operator,
      qualification_snapshot: qualification_snapshot,
      handed_off_at: Time.current
    }
  end

  def assign_operator!(handoff)
    conversation.reload.with_lock do
      conversation.assignee = handoff.assignee
      conversation.assignee_agent_bot = nil
      conversation.status = :open
      conversation.waiting_since ||= Time.current
      conversation.control_state = :human_active
      conversation.control_version += 1
      conversation.save!
    end
  end

  def deliver_alerts!(handoff)
    recipients = alert_recipients(handoff.assignee)
    deliveries = recipients.map { |recipient| deliver_alert(recipient) }
    handoff.update!(alert_recipients: recipients, alert_deliveries: deliveries)
  end

  def deliver_alert(recipient)
    {
      recipient: recipient,
      status: 'sent',
      provider_message_id: text_message_client.send_text!(recipient: recipient, content: alert_text)
    }
  rescue StandardError => e
    {
      recipient: recipient,
      status: 'failed',
      error: e.message
    }
  end

  def alert_recipients(assignee)
    alert_routes.filter_map { |route| recipient_for(route, assignee) }.flatten.uniq
  end

  def alert_routes
    Array(account.settings&.dig('ai_lead_employee', 'alert_routes', ALERT_TYPE))
  end

  def recipient_for(route, assignee)
    case route.to_h['type']
    when 'assignee'
      whatsapp_alert_phone_for(assignee)
    when 'admin'
      account.administrators.map { |admin| whatsapp_alert_phone_for(admin) }
    else
      route.to_h['recipient']
    end
  end

  def whatsapp_alert_phone_for(user)
    return if user.blank?

    user.custom_attributes&.dig('whatsapp_alert_phone').presence
  end

  def configured_operator
    operator_id = account.settings&.dig('ai_lead_employee', 'human_operator_id')
    account.users.find_by(id: operator_id) || account.administrators.first
  end

  def qualification_snapshot
    {
      'quality' => qualification.quality,
      'score' => qualification.score,
      'reasons' => qualification.reasons,
      'missing_signals' => qualification.missing_signals,
      'evidence' => qualification.evidence_snapshot,
      'configuration_version' => qualification.configuration_version
    }
  end

  def alert_text
    evidence = qualification.evidence_snapshot

    [
      'Hot Lead handoff',
      "Conversation: #{conversation_url}",
      "Contact: #{conversation.contact.name} #{conversation.contact.phone_number} #{conversation.contact.email}".squish,
      "Business type: #{value_for(evidence, 'business_type')}",
      "Problem: #{value_for(evidence, 'problem')}",
      "Lead volume: #{value_for(evidence, 'lead_volume')}",
      "Urgency: #{value_for(evidence, 'urgency')}",
      "Budget signal: #{value_for(evidence, 'budget')}",
      "Decision authority: #{value_for(evidence, 'decision_authority')}",
      "Qualification reasons: #{qualification.reasons.join('; ')}"
    ].join("\n")
  end

  def value_for(evidence, signal)
    evidence.dig(signal, 'value').presence || 'Not provided'
  end

  def conversation_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    return path if base_url.blank?

    "#{base_url.delete_suffix('/')}#{path}"
  end

  def whatsapp_channel
    @whatsapp_channel ||= conversation.inbox.channel
  end

  def text_message_client
    @text_message_client ||= Meta::Whatsapp::TextMessageClient.new(whatsapp_channel: whatsapp_channel)
  end
end
