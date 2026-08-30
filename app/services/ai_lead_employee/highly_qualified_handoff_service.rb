# frozen_string_literal: true

class AiLeadEmployee::HighlyQualifiedHandoffService
  ALERT_TYPE = 'highly_qualified_sales_handoff'
  DEFAULT_UNQUALIFIED_HUMAN_REQUEST_EXPLANATION =
    'I need to confirm a few details first so the right Human Operator can help you.'

  Result = Struct.new(:handoff, :created, :assignee, :alert_message_ids, keyword_init: true)

  def initialize(conversation:, qualification:, defer_alert_delivery: false)
    @conversation = conversation
    @qualification = qualification
    @account = conversation.account
    @defer_alert_delivery = defer_alert_delivery
  end

  def perform
    existing_handoff = existing_handoff_record
    return retry_existing_handoff_if_allowed(existing_handoff) if existing_handoff.present?
    return Result.new unless automatic_handoff_allowed?

    handoff, created = find_or_create_handoff!
    assign_operator!(handoff) if created
    alert_message_ids = deliver_alerts!(handoff)
    Result.new(handoff: handoff.reload, created: created, assignee: handoff.assignee, alert_message_ids: alert_message_ids)
  rescue ActiveRecord::RecordNotUnique
    handoff = account.lead_handoffs.find_by!(
      conversation: conversation,
      lead_qualification: qualification,
      alert_type: ALERT_TYPE
    )
    retry_existing_handoff_if_allowed(handoff)
  end

  def self.unqualified_human_request_explanation(account)
    account.settings&.dig('ai_lead_employee', 'unqualified_human_request_explanation').presence ||
      DEFAULT_UNQUALIFIED_HUMAN_REQUEST_EXPLANATION
  end

  private

  attr_reader :account, :conversation, :qualification, :defer_alert_delivery

  def existing_handoff_record
    return if qualification.blank?

    account.lead_handoffs.find_by(
      conversation: conversation,
      lead_qualification: qualification,
      alert_type: ALERT_TYPE
    )
  end

  def retry_existing_handoff_if_allowed(handoff)
    return Result.new unless existing_handoff_retry_allowed?(handoff)

    retry_existing_handoff(handoff)
  end

  def retry_existing_handoff(handoff)
    alert_message_ids = deliver_alerts!(handoff)
    Result.new(handoff: handoff.reload, created: false, assignee: handoff.assignee, alert_message_ids: alert_message_ids)
  end

  def existing_handoff_retry_allowed?(handoff)
    qualification.account_id == account.id &&
      qualification.contact_id == conversation.contact_id &&
      handoff.account_id == account.id &&
      handoff.conversation_id == conversation.id &&
      conversation.human_active? &&
      conversation.open?
  end

  def automatic_handoff_allowed?
    qualification&.highly_qualified? &&
      qualification.account_id == account.id &&
      qualification.contact_id == conversation.contact_id &&
      conversation.ai_active? &&
      conversation.assignee_id.blank? &&
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
    AiLeadEmployee::HandoffAlertDeliveryService.new(
      handoff: handoff,
      alert_text: alert_text,
      recipients: recipients,
      alert_template_params: alert_template_params,
      enqueue: !defer_alert_delivery
    ).perform.message_ids_to_deliver
  end

  def alert_recipients(assignee)
    alert_routes.filter_map { |route| recipient_for(route, assignee) }.flatten.filter_map { |recipient| normalized_recipient(recipient) }.uniq
  end

  def alert_routes
    Array(account.settings&.dig('ai_lead_employee', 'alert_routes', ALERT_TYPE))
  end

  def alert_template_params
    AiLeadEmployee::HandoffAlertTemplateParams.new(
      account: account,
      conversation: conversation,
      qualification: qualification,
      alert_type: ALERT_TYPE
    ).to_h
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

  def normalized_recipient(recipient)
    value = recipient.to_s.strip
    return if value.blank?
    return value if value.match?(RegexHelper::WHATSAPP_BSUID_REGEX)

    value.delete('^0-9').presence
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
    AiLeadEmployee::HandoffAlertText.new(
      account: account,
      conversation: conversation,
      qualification: qualification
    ).to_s
  end
end
