# frozen_string_literal: true

class Webhooks::Meta::WhatsappController < ActionController::API
  SIGNATURE_HEADER = 'X-Hub-Signature-256'
  SIGNATURE_PREFIX = 'sha256='

  before_action :verify_signature!, only: :events

  def verify
    if params['hub.mode'] == 'subscribe' && secure_compare(params['hub.verify_token'], meta_webhook_verify_token)
      render plain: params['hub.challenge'], status: :ok
    else
      head :unauthorized
    end
  end

  def events
    Meta::Whatsapp::InboundWebhookProcessor.new(payload: parsed_payload).perform
    head :ok
  rescue Meta::Whatsapp::InboundWebhookProcessor::UnknownPhoneNumber
    head :not_found
  end

  private

  def parsed_payload
    JSON.parse(request.raw_post)
  end

  def verify_signature!
    return if valid_signature?

    head :unauthorized
  end

  def valid_signature?
    signature = request.headers[SIGNATURE_HEADER]
    return false unless signature&.start_with?(SIGNATURE_PREFIX)
    return false if meta_app_secret.blank?

    secure_compare(
      "#{SIGNATURE_PREFIX}#{OpenSSL::HMAC.hexdigest('SHA256', meta_app_secret, request.raw_post)}",
      signature
    )
  end

  def meta_webhook_verify_token
    GlobalConfigService.load('META_WEBHOOK_VERIFY_TOKEN', nil)
  end

  def meta_app_secret
    GlobalConfigService.load('META_APP_SECRET', nil)
  end

  def secure_compare(left, right)
    return false if left.blank? || right.blank?
    return false unless left.bytesize == right.bytesize

    ActiveSupport::SecurityUtils.secure_compare(left, right)
  end
end
