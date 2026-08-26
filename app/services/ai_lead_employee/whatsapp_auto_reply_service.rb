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
    qualification_result = qualification_result_for_supported_message
    review_request_result = create_review_request(result, qualification_result)
    record_ai_employee_decision!(result, qualification_result, review_request_result)

    sent_message = Meta::Whatsapp::OutboundMessageSender.new(
      conversation: conversation,
      content: reply_content(result, qualification_result),
      expected_control_version: conversation.control_version
    ).perform
    Conversations::ControlService.new(conversation: conversation).handoff_requested! if review_request_result&.request&.open?
    sent_message
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

  def qualification_result_for_supported_message
    return if provider_message_payload[:type] != 'text'

    AiLeadEmployee::QualificationService.new(
      conversation: conversation,
      incoming_message: incoming_message
    ).perform
  end

  def create_review_request(result, qualification_result)
    reason = result.refusal_reason || qualification_result&.review_request_reason
    return unless review_request_reason?(reason)

    AiLeadEmployee::HumanReviewRequestService.new(
      conversation: conversation,
      lead_message: incoming_message,
      reason: reason
    ).perform
  end

  def review_request_reason?(reason)
    reason.in?(%w[no_approved_knowledge conflicting_knowledge sensitive_question qualification_blocker angry_question])
  end

  def reply_content(result, qualification_result)
    return result.answer if result.refused?
    return result.answer if qualification_result&.next_question.blank?

    [result.answer, qualification_result.next_question].join("\n\n")
  end

  def record_ai_employee_decision!(result, qualification_result, review_request_result)
    conversation.update!(
      additional_attributes: conversation.additional_attributes.merge(
        'ai_employee_last_decision' => {
          'status' => result.answered? && result.sources.present? ? 'answered' : 'refused',
          'refusal_reason' => result.refusal_reason,
          'sources' => result.sources.map(&:stringify_keys),
          'human_review_request_id' => review_request_result&.request&.id,
          'qualification' => qualification_result_payload(qualification_result)
        }
      )
    )
  end

  def qualification_result_payload(qualification_result)
    return nil if qualification_result.blank?

    {
      'quality' => qualification_result.qualification.quality,
      'score' => qualification_result.qualification.score,
      'missing_signals' => qualification_result.qualification.missing_signals,
      'next_question' => qualification_result.next_question,
      'configuration_version' => qualification_result.qualification.configuration_version
    }
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
