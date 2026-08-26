# frozen_string_literal: true

class AiLeadEmployee::WhatsappAutoReplyService
  VOICE_NOTE_TEXT_REQUEST = 'Please send the voice note content as text so I can help from approved business information.'

  def initialize(conversation:, incoming_message:, provider_message_payload:)
    @conversation = conversation
    @incoming_message = incoming_message
    @provider_message_payload = provider_message_payload
  end

  def perform
    result = ai_employee_result
    record_ai_employee_decision!(result)

    Meta::Whatsapp::OutboundMessageSender.new(
      conversation: conversation,
      content: result.answer,
      expected_control_version: conversation.control_version
    ).perform
  rescue Meta::Whatsapp::OutboundMessageSender::BlockedByControlState
    nil
  rescue Meta::Whatsapp::OutboundMessageSender::MetaSendFailed => e
    record_send_failure!(e.message)
    nil
  end

  private

  attr_reader :conversation, :incoming_message, :provider_message_payload

  def ai_employee_result
    return voice_note_result if provider_message_payload[:type] != 'text'

    AiLeadEmployee::KnowledgeAnswerService.new(
      account: conversation.account,
      question: incoming_message.content
    ).perform
  end

  def voice_note_result
    AiLeadEmployee::KnowledgeAnswerService::Result.new(
      answer: VOICE_NOTE_TEXT_REQUEST,
      sources: [],
      refusal_reason: 'unsupported_voice_note'
    )
  end

  def record_ai_employee_decision!(result)
    conversation.update!(
      additional_attributes: conversation.additional_attributes.merge(
        'ai_employee_last_decision' => {
          'status' => result.answered? && result.sources.present? ? 'answered' : 'refused',
          'refusal_reason' => result.refusal_reason,
          'sources' => result.sources.map(&:stringify_keys)
        }
      )
    )
  end

  def record_send_failure!(error)
    conversation.update!(
      additional_attributes: conversation.additional_attributes.merge(
        'ai_employee_last_decision' => conversation.additional_attributes['ai_employee_last_decision'].merge(
          'status' => 'send_failed',
          'send_error' => error
        )
      )
    )
  end
end
