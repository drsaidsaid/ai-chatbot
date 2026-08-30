# https://docs.360dialog.com/whatsapp-api/whatsapp-api/media
# https://developers.facebook.com/docs/whatsapp/api/media/

class Whatsapp::IncomingMessageWhatsappCloudService < Whatsapp::IncomingMessageBaseService
  def perform
    processed_params
    new_provider_message = new_provider_message?
    super
    record_coexistence_echo_takeover! if new_provider_message && outgoing_echo
    record_orchestration_intent! if new_provider_message
  end

  private

  def processed_params
    @processed_params ||= params[:entry].try(:first).try(:[], 'changes').try(:first).try(:[], 'value')
  end

  def new_provider_message?
    return false if messages_data.blank?

    Message.find_by(source_id: messages_data.first[:id]).blank?
  end

  def record_coexistence_echo_takeover!
    return unless @message&.outgoing?
    return if @message.content_attributes['external_echo'].blank?

    Conversations::ControlService.new(conversation: @message.conversation).coexistence_echo!
  end

  def record_orchestration_intent!
    AiLeadEmployee::OrchestrationIntentRecorder.new(message: @message).perform
  end

  def download_attachment_file(attachment_payload)
    url_response = HTTParty.get(
      inbox.channel.media_url(attachment_payload[:id]),
      headers: inbox.channel.api_headers
    )

    # This url response will be failure if the access token has expired.
    inbox.channel.authorization_error! if url_response.unauthorized?

    return unless url_response.success?

    downloaded_file = Down.download(url_response.parsed_response['url'], headers: inbox.channel.api_headers)
    # WhatsApp Cloud sends the original filename in the payload; preserve it so accented
    # names keep their correct extension instead of relying on the mangled remote metadata.
    filename = attachment_payload[:filename]
    downloaded_file.define_singleton_method(:original_filename) { filename } if filename.present?
    downloaded_file
  end
end
