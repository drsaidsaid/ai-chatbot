# frozen_string_literal: true

class AiLeadEmployee::HumanReviewRequestService
  Result = Struct.new(:request, :created, keyword_init: true)

  ALERT_TEXT_PREFIX = 'Human review needed'

  def initialize(conversation:, lead_message:, reason:)
    @conversation = conversation
    @lead_message = lead_message
    @reason = reason
  end

  def perform
    request, created = find_or_create_request

    deliver_alerts!(request) if created
    Result.new(request: request, created: created)
  rescue ActiveRecord::RecordNotUnique
    Result.new(
      request: conversation.account.human_review_requests.find_by!(
        conversation: conversation,
        lead_message: lead_message,
        reason: reason
      ),
      created: false
    )
  end

  private

  attr_reader :conversation, :lead_message, :reason

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

  def deliver_alerts!(request)
    recipients = alert_recipients
    deliveries = recipients.map { |recipient| deliver_alert(recipient) }
    request.update!(alert_recipients: recipients, alert_deliveries: deliveries)
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

  def alert_text
    "#{ALERT_TEXT_PREFIX}: #{lead_message.content.to_s.truncate(120)}"
  end

  def alert_recipients
    Array(conversation.account.settings&.dig('ai_review_alert_recipients')).filter_map(&:presence).uniq
  end

  def whatsapp_channel
    @whatsapp_channel ||= conversation.inbox.channel
  end

  def text_message_client
    @text_message_client ||= Meta::Whatsapp::TextMessageClient.new(whatsapp_channel: whatsapp_channel)
  end
end
