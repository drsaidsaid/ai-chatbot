class Whatsapp::OutboundEligibility
  def initialize(delivery:, channel:, recipient:, template: nil)
    @delivery = delivery
    @message = delivery.message.reload
    @conversation = delivery.conversation
    @channel = channel.reload
    @recipient = recipient
    @template = template
  end

  def failure_code
    return 'invalid_message' unless valid_message?

    code = authority_failure
    return code if code

    return approved_template? ? nil : 'template_unavailable' if @template
    return 'message_window_closed' unless @conversation.can_reply?

    nil
  end

  private

  def authority_failure
    return 'account_inactive' unless @delivery.account.reload.active?
    return 'connection_unavailable' unless connection_available?
    return sender_allowed? ? nil : 'sender_access_revoked' if human?

    automation_failure
  end

  def approved_template?
    template = @template.with_indifferent_access
    Array(@channel.message_templates).any? do |item|
      item['name'] == template[:name] && item['language'] == template[:lang_code] && item['status'].to_s.casecmp?('approved')
    end
  end

  def valid_message?
    eligible_payload? && matching_account? && matching_conversation? && valid_recipient?
  end

  def eligible_payload?
    @message.persisted? && !@message.private? && (@message.outgoing? || @message.template?) &&
      @message.source_id.blank? && @message.content_attributes['deleted'] != true
  end

  def matching_account?
    @message.account_id == @delivery.account_id && @conversation.account_id == @delivery.account_id &&
      @channel.account_id == @delivery.account_id && @conversation.contact.account_id == @delivery.account_id
  end

  def matching_conversation?
    @message.conversation_id == @conversation.id && @message.inbox_id == @conversation.inbox_id &&
      @conversation.inbox.channel == @channel && @conversation.additional_attributes['evaluation_sandbox'] != true
  end

  def valid_recipient?
    @recipient.present? && @recipient.to_s == @conversation.contact_inbox&.source_id.to_s
  end

  def connection_available?
    return false if @channel.provider_config['api_key'].blank?
    return false if @channel.provider == 'whatsapp_cloud' && !@channel.connection_configured?

    @channel.phone_number_health_error.blank? &&
      Whatsapp::HealthService::RISKY_STATUSES.exclude?(@channel.phone_number_health['status'])
  end

  def human?
    @message.sender_type == 'User'
  end

  def sender_allowed?
    membership = AccountUser.lock.find_by(account_id: @delivery.account_id, user_id: @message.sender_id)
    membership && (membership.administrator? || @conversation.assignee_id == @message.sender_id)
  end

  def follow_up_current?
    follow_up_id = @message.additional_attributes.dig('ai_lead_employee', 'follow_up_id')
    return true unless follow_up_id

    follow_up = LeadFollowUp.find_by(account_id: @delivery.account_id, id: follow_up_id, conversation_id: @conversation.id,
                                     contact_id: @conversation.contact_id, message_id: @message.id)
    follow_up&.pending? && follow_up.control_version == @conversation.control_version && follow_up.scheduled_at <= Time.current
  end

  def automation_failure
    return 'control_changed' unless @conversation.open? && @conversation.control_version == @delivery.observed_control_version
    return 'launch_not_approved' unless AiLeadEmployee::LaunchGate.live_ai_enabled?(@delivery.account)

    alert = Whatsapp::OutboundAlertAuthority.new(@message)
    return alert.failure_code if alert.alert?

    lead_failure = lead_automation_failure
    return lead_failure if lead_failure
    return unless provider_control_required?

    attributes = @message.additional_attributes.fetch('ai_lead_employee', {})
    AiLeadEmployee::AiProvider::RuntimeControl.failure_code(
      account: @delivery.account,
      configuration_version: attributes['provider_configuration_version'],
      usage_period_on: attributes['provider_usage_period_on']
    )
  end

  def provider_control_required?
    attributes = @message.additional_attributes.fetch('ai_lead_employee', {})
    return false if @message.template? || attributes['delivery_type'].in?(%w[qualification_follow_up booking_confirmation])

    @message.sender_type != 'User' || attributes['orchestration_intent_id'].present?
  end

  def lead_automation_failure
    return 'control_changed' unless @conversation.ai_active? && @conversation.assignee_id.nil?
    return 'opted_out' if LeadFollowUpOptOut.exists?(account_id: @delivery.account_id, contact_id: @conversation.contact_id)
    return 'follow_up_canceled' unless follow_up_current?
    return 'human_activity' if @conversation.messages.where('id > ?', @message.id).exists?(sender_type: 'User', message_type: :outgoing)

    nil
  end
end
