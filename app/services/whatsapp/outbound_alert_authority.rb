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

  def failure_code
    return 'alert_authority_unavailable' unless record

    # The dispatch transaction already owns Conversation and delivery locks.
    # Serialize all authority updates, including the review rejection API, until
    # dispatching commits. Provider HTTP begins only after these locks are released.
    record.lock!
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
    @record ||= case @attributes['alert_type']
                when 'human_review_request'
                  HumanReviewRequest.find_by(account_id: @message.account_id, id: @attributes['review_request_id'])
                when AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE
                  LeadHandoff.find_by(account_id: @message.account_id, id: @attributes['handoff_id'])
                when AiLeadEmployee::BookingService::PREPARATION_ALERT_TYPE
                  Booking.find_by(account_id: @message.account_id, id: @attributes['booking_id'])
                end
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
    return Array(account.settings&.dig('ai_review_alert_recipients')).map { |value| normalize(value) } if record.is_a?(HumanReviewRequest)

    recipients = alert_routes(account).flat_map { |route| route_recipients(route, account) }
    recipients.filter_map { |value| normalize(value) }.uniq
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
      user = record.conversation.assignee
      user.custom_attributes['whatsapp_alert_phone'] if user && AccountUser.exists?(account_id: account.id, user_id: user.id)
    else
      route.to_h['recipient']
    end
  end

  def normalize(value)
    Whatsapp::RecipientIdentifier.normalize(value)
  end
end
