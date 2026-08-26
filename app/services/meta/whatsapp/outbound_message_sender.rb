# frozen_string_literal: true

class Meta::Whatsapp::OutboundMessageSender
  class BlockedByControlState < StandardError; end
  class MetaSendFailed < StandardError; end

  def initialize(conversation:, content:, expected_control_version:)
    @conversation = conversation
    @content = content
    @expected_control_version = expected_control_version
  end

  def perform
    conversation.reload.with_lock do
      raise BlockedByControlState unless allowed_to_send?

      response = send_to_meta
      create_message!(response.fetch('messages').first.fetch('id'))
    end
  end

  private

  attr_reader :conversation, :content, :expected_control_version

  def allowed_to_send?
    conversation.ai_active? &&
      conversation.open? &&
      conversation.assignee_id.blank? &&
      conversation.control_version == expected_control_version
  end

  def send_to_meta
    uri = URI("https://graph.facebook.com/#{graph_api_version}/#{whatsapp_channel.provider_config.fetch('phone_number_id')}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{whatsapp_channel.provider_config.fetch('api_key')}"
    request['Content-Type'] = 'application/json'
    request.body = request_body.to_json

    response = http.request(request)
    raise MetaSendFailed, response.body unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def request_body
    {
      messaging_product: 'whatsapp',
      to: conversation.contact_inbox.source_id,
      type: 'text',
      text: { body: content }
    }
  end

  def create_message!(external_message_id)
    Message.create!(
      account: conversation.account,
      inbox: conversation.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content_type: :text,
      content: content,
      status: :sent,
      source_id: external_message_id
    )
  end

  def whatsapp_channel
    @whatsapp_channel ||= conversation.inbox.channel
  end

  def graph_api_version
    ENV.fetch('META_GRAPH_API_VERSION', 'v23.0')
  end
end
