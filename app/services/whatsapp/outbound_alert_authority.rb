# frozen_string_literal: true

# Operator alerts are authorized by their originating domain record, not by the
# notification Conversation (which deliberately belongs to human control).
class Whatsapp::OutboundAlertAuthority
  def initialize(message)
    @message = message
    @attributes = message.additional_attributes.fetch('ai_lead_employee', {})
  end

  def alert?
    @attributes['alert_type'].present?
  end

  def origin_id
    @attributes['origin_conversation_id'] if alert?
  end

  def lock_record!
    return unless @message.present? && @message.persisted? && record

    record.lock!
  end

  def failure_code
    return 'alert_authority_unavailable' unless record

    return knowledge_alert_failure if knowledge_alert?

    subscription_alert? ? subscription_alert_failure : conversation_alert_failure
  end

  def conversation_alert_failure
    # Canonical dispatch already owns this record before Delivery. Do not acquire
    # a new earlier-rank domain lock from this eligibility check.
    return 'alert_authority_unavailable' unless origin_id == record.conversation_id

    origin = record.conversation.reload
    return 'control_changed' unless origin_current?(origin)
    return 'alert_authority_unavailable' unless record_current? && origin.inbox_id == @message.inbox_id
    return 'opted_out' if LeadFollowUpOptOut.exists?(account_id: @message.account_id, contact_id: origin.contact_id)

    recipient_failure
  end

  def origin_current?(origin)
    origin.open? && origin.control_version == @attributes['origin_control_version']
  end

  def recipient_failure
    return 'alert_recipient_removed' unless current_recipients.include?(normalize(@attributes['alert_recipient']))
    return 'invalid_recipient' unless normalize(@attributes['alert_recipient']) == @message.conversation.contact_inbox.source_id

    nil
  end

  private

  def record
    return @record if instance_variable_defined?(:@record)

    @record = case @attributes['alert_type']
              when 'human_review_request'
                HumanReviewRequest.find_by(account_id: @message.account_id, id: @attributes['review_request_id'])
              when AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE
                LeadHandoff.find_by(account_id: @message.account_id, id: @attributes['handoff_id'])
              when AiLeadEmployee::BookingService::PREPARATION_ALERT_TYPE
                Booking.find_by(account_id: @message.account_id, id: @attributes['booking_id'])
              when AiLeadEmployee::SubscriptionAlertDeliveryService::ALERT_TYPE
                AiLeadEmployee::AiSubscriptionAlert.find_by(
                  account_id: @message.account_id, id: @attributes['ai_subscription_alert_id']
                )
              when AiLeadEmployee::KnowledgeApprovalAlertDeliveryService::ALERT_TYPE
                KnowledgeItem.find_by(account_id: @message.account_id, id: @attributes['knowledge_item_id'])
              end
  end

  def subscription_alert_failure
    return 'alert_authority_unavailable' unless record.open?
    return 'alert_recipient_removed' unless current_recipients.include?(normalize(@attributes['alert_recipient']))
    return 'invalid_recipient' unless normalize(@attributes['alert_recipient']) == @message.conversation.contact_inbox.source_id

    nil
  end

  def knowledge_alert_failure
    return 'control_changed' unless record.draft?
    return 'alert_recipient_removed' unless current_recipients.include?(normalize(@attributes['alert_recipient']))
    return 'invalid_recipient' unless normalize(@attributes['alert_recipient']) == @message.conversation.contact_inbox.source_id

    nil
  end

  def subscription_alert?
    record.is_a?(AiLeadEmployee::AiSubscriptionAlert)
  end

  def knowledge_alert?
    record.is_a?(KnowledgeItem)
  end

  def record_current?
    current = record.is_a?(Booking) ? record.confirmed? : record.open?
    return false unless current
    return true if record.is_a?(HumanReviewRequest) || record.assignee_id.nil?

    record.assignee_id == record.conversation.assignee_id &&
      AccountUser.exists?(account_id: @message.account_id, user_id: record.assignee_id)
  end

  def current_recipients
    account = @message.account.reload
    return subscription_alert_recipients if subscription_alert?
    if record.is_a?(HumanReviewRequest) && alert_routes(account).empty?
      return Array(account.settings&.dig('ai_review_alert_recipients')).map { |value| normalize(value) }
    end

    routed_recipients(account)
  end

  def subscription_alert_recipients
    Whatsapp::SubscriptionAlertRecipientResolver.for(@message.account)
  end

  def routed_recipients(account)
    alert_routes(account).flat_map { |route| route_recipients(route, account) }.filter_map { |value| normalize(value) }.uniq
  end

  def alert_routes(account)
    routes = Array(account.settings&.dig('ai_lead_employee', 'alert_routes', @attributes['alert_type']))
    routes = [{ 'type' => 'assignee' }] if routes.empty? && record.is_a?(Booking)
    routes
  end

  def route_recipients(route, account)
    case route.to_h['type']
    when 'admin'
      account.administrators.map { |user| user.custom_attributes['whatsapp_alert_phone'] }
    when 'assignee'
      assignee_alert_phone(account)
    when 'member'
      member_alert_phone(route, account)
    when 'whatsapp'
      route.to_h['recipient']
    end
  end

  def assignee_alert_phone(account)
    user = knowledge_alert? ? account.users.find_by(id: account.settings&.dig('ai_lead_employee', 'human_operator_id')) : record.conversation.assignee
    user.custom_attributes['whatsapp_alert_phone'] if user && AccountUser.exists?(account_id: account.id, user_id: user.id)
  end

  def member_alert_phone(route, account)
    account.users.find_by(id: route.to_h['user_id'])&.custom_attributes&.dig('whatsapp_alert_phone')
  end

  def normalize(value)
    Whatsapp::RecipientIdentifier.normalize(value)
  end
end
