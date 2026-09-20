# frozen_string_literal: true

class AiLeadEmployee::HighlyQualifiedHandoffService # rubocop:disable Metrics/ClassLength
  ALERT_TYPE = 'highly_qualified_sales_handoff'
  SALES_CALL_AGREEMENT_FIELD = 'sales_call_agreement'
  SALES_CALL_DIMENSIONS = %w[fit readiness action_eligibility].freeze
  DEFAULT_UNQUALIFIED_HUMAN_REQUEST_EXPLANATION =
    'I need to confirm a few details first so the right Human Operator can help you.'

  Result = Struct.new(:handoff, :created, :assignee, :alert_message_ids, keyword_init: true)

  def initialize(conversation:, qualification:, qualification_context: nil, defer_alert_delivery: false, suppress_external_alerts: false)
    @conversation = conversation
    @qualification = qualification
    @qualification_context = qualification_context
    @account = conversation.account
    @defer_alert_delivery = defer_alert_delivery
    @suppress_external_alerts = suppress_external_alerts
  end

  def perform
    result = conversation.reload.with_lock('FOR NO KEY UPDATE') do
      perform_handoff_locked
    end
    deliver_result_alerts(result)
  rescue ActiveRecord::RecordNotUnique
    result = conversation.reload.with_lock('FOR NO KEY UPDATE') do
      recover_existing_handoff_locked
    end
    deliver_result_alerts(result)
  end

  def self.unqualified_human_request_explanation(account)
    account.settings&.dig('ai_lead_employee', 'unqualified_human_request_explanation').presence ||
      DEFAULT_UNQUALIFIED_HUMAN_REQUEST_EXPLANATION
  end

  private

  def perform_handoff_locked
    existing_handoff = existing_handoff_record
    context = existing_handoff ? existing_handoff.qualification_snapshot['qualification_context'] : qualification_context
    authority = AiLeadEmployee::OfferDeliveryContext.new(
      conversation: conversation, context: context, required: qualification&.offer_id.present?
    )
    authority.lock_offers!
    if existing_handoff
      return Result.new if authority.failure_code || !existing_handoff_retry_allowed?(existing_handoff)

      return Result.new(handoff: existing_handoff, created: false, assignee: existing_handoff.assignee)
    end
    create_handoff_result(authority)
  end

  def create_handoff_result(authority)
    return Result.new unless context_matches_qualification?
    return Result.new if authority.failure_code

    qualification&.reload
    return Result.new unless automatic_handoff_allowed?

    handoff, created = find_or_create_handoff!
    assign_operator!(handoff) if created
    Result.new(handoff: handoff, created: created, assignee: handoff.assignee)
  end

  def recover_existing_handoff_locked
    handoff = account.lead_handoffs.find_by!(conversation: conversation, lead_qualification: qualification, alert_type: ALERT_TYPE)
    authority = AiLeadEmployee::OfferDeliveryContext.new(
      conversation: conversation, context: handoff.qualification_snapshot['qualification_context'],
      required: qualification&.offer_id.present?
    )
    authority.lock_offers!
    return Result.new if authority.failure_code || !existing_handoff_retry_allowed?(handoff)

    Result.new(handoff: handoff, created: false, assignee: handoff.assignee)
  end

  attr_reader :account, :conversation, :qualification, :qualification_context, :defer_alert_delivery, :suppress_external_alerts

  def deliver_result_alerts(result)
    return result unless result.handoff

    if suppress_external_alerts
      result.handoff.update!(
        alert_recipients: [],
        alert_deliveries: [{ 'status' => 'suppressed', 'reason' => 'pilot_external_alert_not_authorized', 'at' => Time.current.iso8601 }]
      )
      result.alert_message_ids = []
      return result
    end

    result.alert_message_ids = deliver_alerts!(result.handoff)
    result.handoff.reload
    result
  end

  def existing_handoff_record
    return if qualification.blank?

    account.lead_handoffs.find_by(
      conversation: conversation,
      lead_qualification: qualification,
      alert_type: ALERT_TYPE
    )
  end

  def context_matches_qualification?
    return qualification&.offer_id.nil? if qualification_context.blank?

    qualification && qualification_context['qualification_id'] == qualification.id &&
      qualification_context['offer_id'] == qualification.offer_id
  end

  def existing_handoff_retry_allowed?(handoff)
    qualification.account_id == account.id &&
      qualification.contact_id == conversation.contact_id &&
      handoff.account_id == account.id &&
      handoff.conversation_id == conversation.id &&
      handoff.open? &&
      conversation.human_active? &&
      conversation.open?
  end

  def automatic_handoff_allowed?
    qualification.present? &&
      qualification.account_id == account.id &&
      qualification.contact_id == conversation.contact_id &&
      conversation.ai_active? &&
      conversation.assignee_id.blank? &&
      qualification_action_allowed?
  end

  def qualification_action_allowed?
    return legacy_highly_qualified? unless qualification.offer
    return false unless qualification.offer.next_step['kind'] == 'sales_call'
    return false if qualification.unqualified?

    valid_sales_call_assessment? && explicit_sales_call_agreement?
  end

  def valid_sales_call_assessment?
    assessment = qualification.assessment
    assessment.is_a?(Hash) && SALES_CALL_DIMENSIONS.all? do |dimension|
      dimension_assessment = assessment[dimension]
      dimension_assessment.is_a?(Hash) && dimension_assessment['status'] == expected_dimension_status(dimension) &&
        dimension_assessment['missing_fields'] == [] && dimension_assessment['reasons'] == []
    end
  end

  def expected_dimension_status(dimension)
    sales_call_dimension_configured?(dimension) ? 'met' : 'not_required'
  end

  def sales_call_dimension_configured?(dimension)
    return true if configured_required_question?(dimension)
    return true if qualification.offer.configuration.fetch('rules', []).any? do |rule|
      rule['enabled'] && rule['kind'] == 'requirement' && rule['dimension'] == dimension
    end

    qualification.offer.configuration.fetch('requirement_groups', []).any? { |group| group['dimension'] == dimension }
  end

  def configured_required_question?(dimension)
    qualification.offer.questions.any? do |question|
      question['enabled'] && question['required'] && question.fetch('purpose', 'fit') == dimension
    end
  end

  def explicit_sales_call_agreement?
    question = qualification.offer.questions.find { |candidate| candidate['key'] == SALES_CALL_AGREEMENT_FIELD }
    return false unless question&.[]('answer_type') == 'boolean'

    agreement = qualification.evidence_snapshot[SALES_CALL_AGREEMENT_FIELD]
    agreement.is_a?(Hash) && agreement['typed_value'] == true && agreement['polarity'] == 'positive'
  end

  def legacy_highly_qualified?
    qualification.highly_qualified? &&
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
    AiLeadEmployee::HandoffAlertRecipients.new(account: account, alert_type: ALERT_TYPE).for(assignee)
  end

  def alert_template_params
    AiLeadEmployee::HandoffAlertTemplateParams.new(
      account: account,
      conversation: conversation,
      qualification: qualification,
      alert_type: ALERT_TYPE
    ).to_h
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
      'assessment' => qualification.assessment,
      'evidence' => qualification.evidence_snapshot,
      'configuration_version' => qualification.configuration_version,
      'qualification_context' => qualification_context
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
