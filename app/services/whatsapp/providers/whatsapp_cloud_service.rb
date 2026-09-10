class Whatsapp::Providers::WhatsappCloudService < Whatsapp::Providers::BaseService # rubocop:disable Metrics/ClassLength
  prepend Whatsapp::OutboundProviderGuard
  def send_message(phone_number, message, &)
    @message = message

    if message.attachments.present?
      send_attachment_message(phone_number, message, &)
    elsif message.content_type == 'input_select'
      send_interactive_text_message(phone_number, message, &)
    else
      send_text_message(phone_number, message, &)
    end
  end

  def send_template(phone_number, template_info, message)
    template_body = template_body_parameters(template_info)

    request_body = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual', # Only individual messages supported (not group messages)
      # BSUID -> `recipient`; phone number -> `to` (see recipient_params in the base provider).
      **recipient_params(phone_number),
      type: 'template',
      template: template_body
    }

    response = yield(
      "#{phone_id_path}/messages",
      headers: api_headers,
      timeout: 10,
      body: request_body.to_json
    )

    process_response(response, message)
  end

  def sync_templates
    # ensuring that channels with wrong provider config wouldn't keep trying to sync templates
    whatsapp_channel.mark_message_templates_updated
    return if (templates = fetch_whatsapp_templates).blank?

    # update_columns skips touch, so bump the cache key ourselves; only if templates changed
    whatsapp_channel.account.update_cache_key('inbox') if templates != whatsapp_channel.message_templates
    # rubocop:disable Rails/SkipsModelValidations
    whatsapp_channel.update_columns(message_templates: templates, message_templates_last_updated: Time.current)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def fetch_whatsapp_templates(after: nil)
    options = { headers: { 'Authorization' => "Bearer #{whatsapp_channel.template_access_token}" } }
    options[:query] = { after: after } if after.present?
    response = HTTParty.get("#{business_account_path}/message_templates", options)
    unless response.success?
      Rails.logger.warn "[WHATSAPP] Template sync failed for account #{whatsapp_channel.account_id} " \
                        "inbox #{whatsapp_channel.inbox&.id}: #{response.code} #{error_message(response)}"
      return []
    end

    next_cursor = response.dig('paging', 'cursors', 'after')

    return response['data'] + fetch_whatsapp_templates(after: next_cursor) if next_cursor.present?

    response['data']
  end

  def validate_provider_config?
    response = HTTParty.get("#{business_account_path}/message_templates", headers: api_headers, timeout: 10)
    return log_transfer_failure('waba_or_token_check', response) unless response.success?
    # Bind the stored routing number and ID to the WABA, including phone-only edits.
    return true unless whatsapp_channel.connection_configuration_changed?

    phone_response = HTTParty.get("#{business_account_path}/phone_numbers?fields=id,display_phone_number&limit=100",
                                  headers: api_headers, timeout: 10)
    numbers = phone_response.parsed_response.is_a?(Hash) ? Array(phone_response.parsed_response['data']) : []
    return true if phone_response.success? && numbers.any? { |number| provider_phone_matches?(number) }

    log_transfer_failure('phone_number_id_check', phone_response)
  end

  def api_headers
    { 'Authorization' => "Bearer #{whatsapp_channel.provider_config['api_key']}", 'Content-Type' => 'application/json' }
  end

  def create_csat_template(template_config)
    csat_template_service.create_template(template_config)
  end

  def delete_csat_template(template_name = nil)
    template_name ||= CsatTemplateNameService.csat_template_name(whatsapp_channel.inbox.id)
    csat_template_service.delete_template(template_name)
  end

  def get_template_status(template_name)
    csat_template_service.get_template_status(template_name)
  end

  def media_url(media_id)
    "#{api_base_path}/v13.0/#{media_id}"
  end

  private

  def provider_phone_matches?(number)
    return false unless number.is_a?(Hash)

    Whatsapp::WebhookChannelFinderService.new(display_phone_number: number['display_phone_number'], phone_number_id: number['id'])
                                         .matches?(whatsapp_channel)
  end

  # Only saves dropping the embedded_signup source marker are transfer attempts; creation/rotation failures are setup errors. Returns false.
  def log_transfer_failure(check, response)
    return false unless whatsapp_channel.embedded_to_manual_transfer_pending?

    Rails.logger.warn("[WHATSAPP_EMBEDDED_TO_MANUAL] failure account_id=#{whatsapp_channel.account_id} channel_id=#{whatsapp_channel.id} " \
                      "check=#{check} http_status=#{response.code}")
    false
  end

  def csat_template_service
    @csat_template_service ||= Whatsapp::CsatTemplateService.new(whatsapp_channel)
  end

  def api_base_path = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')

  # TODO: See if we can unify the API versions and for both paths and make it consistent with out facebook app API versions
  def phone_id_path(version = 'v13.0')
    "#{api_base_path}/#{version}/#{whatsapp_channel.provider_config['phone_number_id']}"
  end

  def business_account_path = "#{api_base_path}/v14.0/#{whatsapp_channel.provider_config['business_account_id']}"

  def send_text_message(phone_number, message)
    response = yield(
      "#{phone_id_path}/messages",
      headers: api_headers,
      timeout: 10,
      body: {
        messaging_product: 'whatsapp',
        context: whatsapp_reply_context(message),
        **recipient_params(phone_number),
        text: { body: message.outgoing_content },
        type: 'text'
      }.to_json
    )

    process_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    normalize_opus_content_type(attachment)
    type = %w[image audio video].include?(attachment.file_type) ? attachment.file_type : 'document'
    type_content = build_attachment_content(type, attachment, message)
    response = yield(
      "#{phone_id_path('v24.0')}/messages",
      headers: api_headers,
      timeout: 10,
      body: {
        :messaging_product => 'whatsapp',
        :context => whatsapp_reply_context(message),
        **recipient_params(phone_number),
        'type' => type,
        type.to_s => type_content
      }.to_json
    )

    process_response(response, message)
  end

  def error_message(response)
    # https://developers.facebook.com/docs/whatsapp/cloud-api/support/error-codes/#sample-response
    response.parsed_response.dig('error', 'message') if response.parsed_response.is_a?(Hash)
  end

  def voice_message?(type, attachment)
    type == 'audio' && attachment.meta&.dig('is_voice_message') && attachment.file.content_type == 'audio/ogg'
  end

  # Marcel gem may re-detect OGG/Opus files as audio/opus after ActiveStorage
  # blob attachment, but WhatsApp Cloud API requires audio/ogg content type
  # for voice messages. Normalize so the download URL serves the correct
  # Content-Type header. No-op when the frontend already uploads as audio/ogg.
  def normalize_opus_content_type(attachment)
    return unless attachment.file.attached?

    blob = attachment.file.blob
    return unless blob.content_type == 'audio/opus'

    return if blob.update(content_type: 'audio/ogg')

    Rails.logger.error("Failed to normalize blob #{blob.id} content_type from audio/opus to audio/ogg")
  end

  def build_attachment_content(type, attachment, message)
    type_content = { 'link' => attachment.download_url }
    type_content['caption'] = message.outgoing_content unless %w[audio sticker].include?(type)
    type_content['filename'] = attachment.file.filename if type == 'document'
    type_content['voice'] = true if voice_message?(type, attachment)
    type_content
  end

  def template_body_parameters(template_info)
    template_body = {
      name: template_info[:name],
      language: {
        policy: 'deterministic',
        code: template_info[:lang_code]
      }
    }

    # Enhanced template parameters structure
    # Note: Legacy format support (simple parameter arrays) has been removed
    # in favor of the enhanced component-based structure that supports
    # headers, buttons, and authentication templates.
    #
    # Expected payload format from frontend:
    # {
    #   processed_params: {
    #     body: { '1': 'John', '2': '123 Main St' },
    #     header: {
    #       media_url: 'https://...',
    #       media_type: 'image',
    #       media_name: 'filename.pdf' # Optional, for document templates only
    #     },
    #     buttons: [{ type: 'url', parameter: 'otp123456' }]
    #   }
    # }
    # This gets transformed into WhatsApp API component format:
    # [
    #   { type: 'body', parameters: [...] },
    #   { type: 'header', parameters: [...] },
    #   { type: 'button', sub_type: 'url', parameters: [...] }
    # ]
    template_body[:components] = template_info[:parameters] || []

    template_body
  end

  def whatsapp_reply_context(message)
    reply_to = message.content_attributes[:in_reply_to_external_id]
    return nil if reply_to.blank?

    {
      message_id: reply_to
    }
  end

  def send_interactive_text_message(phone_number, message)
    payload = create_payload_based_on_items(message)

    response = yield(
      "#{phone_id_path}/messages",
      headers: api_headers,
      timeout: 10,
      body: {
        messaging_product: 'whatsapp',
        **recipient_params(phone_number),
        interactive: payload,
        type: 'interactive'
      }.to_json
    )

    process_response(response, message)
  end
end

Whatsapp::Providers::WhatsappCloudService.prepend_mod_with('Whatsapp::Providers::WhatsappCloudService')
