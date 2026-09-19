# frozen_string_literal: true

class AiLeadEmployee::HumanReviewRequestService
  Result = Struct.new(:request, :created, keyword_init: true)

  ALERT_TYPE = 'human_review_request'
  ALERT_TEXT_PREFIX = 'Human review needed'

  def initialize(conversation:, lead_message:, reason:, enqueue_alerts: true)
    @conversation = conversation
    @lead_message = lead_message
    @reason = reason
    @enqueue_alerts = enqueue_alerts
  end

  def perform
    request, created = find_or_create_request

    ensure_assignment!(request)
    deliver_alerts!(request)
    Result.new(request: request, created: created)
  rescue ActiveRecord::RecordNotUnique
    request = conversation.account.human_review_requests.find_by!(
      conversation: conversation,
      lead_message: lead_message,
      reason: reason
    )
    ensure_assignment!(request)
    deliver_alerts!(request)
    Result.new(request: request, created: false)
  end

  private

  attr_reader :conversation, :lead_message, :reason, :enqueue_alerts

  def find_or_create_request
    request = nil
    created = false

    HumanReviewRequest.transaction(requires_new: true) do
      request = conversation.account.human_review_requests.find_or_initialize_by(
        conversation: conversation,
        lead_message: lead_message,
        reason: reason
      )
      created = request.new_record?
      request.assign_attributes(question: lead_message.content.to_s) if created
      request.save!
    end

    [request, created]
  end

  def ensure_assignment!(request)
    current_owner = conversation.reload.assignee
    request.assign_to!(current_owner || default_owner)
  end

  def deliver_alerts!(request)
    message_ids = ApplicationRecord.transaction do
      locked_conversation = Conversation.where(account_id: conversation.account_id, id: conversation.id)
                                        .lock('FOR NO KEY UPDATE').first!
      request.lock!
      request.reload
      persist_alert_deliveries!(request, locked_conversation)
    end
    enqueue_after_commit(message_ids.uniq) if enqueue_alerts
  end

  def enqueue_after_commit(message_ids)
    ActiveRecord.after_all_transactions_commit do
      message_ids.each { |message_id| SendReplyJob.perform_later(message_id) }
    end
  end

  def persist_alert_deliveries!(request, locked_conversation)
    message_ids = []
    recipients = alert_recipients(request)
    previous_deliveries = request.alert_deliveries.index_by { |delivery| delivery['recipient'] }
    deliveries = recipients.map do |recipient|
      alert_delivery_for(request, locked_conversation, recipient, previous_deliveries[recipient], message_ids)
    end
    request.update!(alert_recipients: recipients, alert_deliveries: deliveries)
    message_ids
  end

  def alert_delivery_for(request, locked_conversation, recipient, previous_delivery, message_ids)
    message = alert_message_from(previous_delivery)
    message ||= create_alert_message!(request, locked_conversation, recipient)
    message_ids << message.id if previous_delivery.blank? || message.failed?

    {
      recipient: recipient,
      status: alert_delivery_status(message),
      message_id: message.id,
      conversation_id: message.conversation_id,
      provider_message_id: message.source_id,
      error: message.external_error
    }.compact
  end

  def alert_message_from(delivery)
    return if delivery.blank?

    message_id = Integer(delivery['message_id'], exception: false)
    return if message_id.blank?

    conversation.account.messages.find_by(id: message_id)
  end

  def create_alert_message!(request, locked_conversation, recipient)
    alert_conversation = AiLeadEmployee::WhatsappAlertConversation.new(
      account: conversation.account,
      whatsapp_channel: whatsapp_channel,
      recipient: recipient,
      alert_type: ALERT_TYPE
    ).perform
    alert_conversation.messages.create!(
      account: conversation.account,
      inbox: whatsapp_channel.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: alert_text(request),
      private: false,
      additional_attributes: alert_additional_attributes(request, locked_conversation, recipient)
    )
  end

  def alert_additional_attributes(request, locked_conversation, recipient)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox',
        review_request_id: request.id,
        origin_conversation_id: locked_conversation.id,
        origin_control_version: locked_conversation.control_version,
        alert_type: ALERT_TYPE,
        alert_recipient: recipient
      }
    }
  end

  def alert_text(request)
    [
      "#{ALERT_TEXT_PREFIX}: #{lead_message.content.to_s.truncate(120)}",
      "Reason: #{request.reason.humanize}",
      "Owner: #{request.assigned_user&.name || 'Unassigned'}",
      "Open: #{conversation_url}"
    ].join("\n")
  end

  def conversation_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}?queue=review"
    base_url ? "#{base_url.delete_suffix('/')}#{path}" : path
  end

  def alert_recipients(request)
    current_account = conversation.account.reload
    routes = current_account.settings&.dig('ai_lead_employee', 'alert_routes', ALERT_TYPE)
    return Array(current_account.settings&.dig('ai_review_alert_recipients')).filter_map(&:presence).uniq if routes.blank?

    AiLeadEmployee::HandoffAlertRecipients.new(account: current_account, alert_type: ALERT_TYPE).for(request.assigned_user)
  end

  def default_owner
    current_account = conversation.account.reload
    operator_id = current_account.settings&.dig('ai_lead_employee', 'human_operator_id')
    current_account.users.find_by(id: operator_id)
  end

  def whatsapp_channel
    @whatsapp_channel ||= conversation.inbox.channel
  end

  def alert_delivery_status(message)
    return 'sent' if message.source_id.present?
    return 'failed' if message.failed?

    'queued'
  end
end
