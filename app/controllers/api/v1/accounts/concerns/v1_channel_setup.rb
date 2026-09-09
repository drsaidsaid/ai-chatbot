module Api::V1::Accounts::Concerns::V1ChannelSetup
  extend ActiveSupport::Concern

  private

  def allowed_channel_types
    %w[web_widget api email line telegram whatsapp sms]
  end

  def ensure_v1_channel_setup
    return if params.dig(:channel, :type) == 'whatsapp' && params.dig(:channel, :provider) == 'whatsapp_cloud'

    render json: { error: 'V1 supports the direct Meta WhatsApp Cloud connection only.' }, status: :unprocessable_entity
  end
end
