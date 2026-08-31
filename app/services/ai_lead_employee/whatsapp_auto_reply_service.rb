# frozen_string_literal: true

class AiLeadEmployee::WhatsappAutoReplyService
  def initialize(conversation:, incoming_message:, provider_message_payload:)
    @conversation = conversation
    @incoming_message = incoming_message
    @provider_message_payload = provider_message_payload
  end

  def perform
    nil
  end
end
