# frozen_string_literal: true

class Meta::Whatsapp::OutboundMessageSender
  class BlockedByControlState < StandardError; end
  MetaSendFailed = Meta::Whatsapp::TextMessageClient::SendFailed

  def initialize(conversation:, content:, expected_control_version:)
    @conversation = conversation
    @content = content
    @expected_control_version = expected_control_version
  end

  def perform
    conversation.reload.with_lock do
      raise BlockedByControlState unless allowed_to_send?

      create_message!(text_message_client.send_text!(recipient: conversation.contact_inbox.source_id, content: content))
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

  def text_message_client
    @text_message_client ||= Meta::Whatsapp::TextMessageClient.new(whatsapp_channel: whatsapp_channel)
  end
end
