# frozen_string_literal: true

class Webhooks::Meta::WhatsappController < ActionController::API
  def verify = retired_path_response

  def events = retired_path_response

  private

  def retired_path_response
    render json: {
      error: 'retired_meta_whatsapp_path',
      canonical_path: '/webhooks/whatsapp/:phone_number',
      canonical_controller: 'Webhooks::WhatsappController'
    }, status: :gone
  end
end
