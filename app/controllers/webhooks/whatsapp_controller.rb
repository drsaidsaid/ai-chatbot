class Webhooks::WhatsappController < ActionController::API
  include MetaTokenVerifyConcern

  def process_payload
    receipt = Whatsapp::ReceiptAcceptor.new(raw_body: request.raw_post, signature: request.headers['X-Hub-Signature-256']).perform
    receipt.enqueue
    render json: { receipt_id: receipt.id }, status: :ok
  rescue Whatsapp::ReceiptAcceptor::InvalidSignature
    head :unauthorized
  rescue Whatsapp::ReceiptAcceptor::InvalidPayload
    head :bad_request
  rescue Whatsapp::ReceiptAcceptor::InactiveChannel
    head :unprocessable_entity
  rescue ActiveRecord::ActiveRecordError
    head :service_unavailable
  end

  private

  def valid_token?(token)
    channel = Channel::Whatsapp.find_by(phone_number: params[:phone_number])
    whatsapp_webhook_verify_token = channel.provider_config['webhook_verify_token'] if channel.present?
    token == whatsapp_webhook_verify_token if whatsapp_webhook_verify_token.present?
  end
end
