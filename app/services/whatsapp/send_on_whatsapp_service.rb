class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    return send_template_message if template_params.present?
    return send_session_message if message.conversation.can_reply?

    message.update!(status: :failed, external_error: I18n.t('errors.whatsapp.message_outside_messaging_window'))
  end

  def send_template_message
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(message.conversation.contact_inbox.source_id, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    mark_message_sent!(message_id)
  end

  def send_session_message
    message_id = channel.send_message(message.conversation.contact_inbox.source_id, message)
    mark_message_sent!(message_id)
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end

  def mark_message_sent!(message_id)
    return if message_id.blank?

    message.update!(source_id: message_id, external_error: nil)
  end
end
