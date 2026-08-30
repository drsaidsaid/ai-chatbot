# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::Meta::WhatsappController', type: :request do
  describe 'GET /webhooks/meta/whatsapp' do
    it 'quarantines the duplicate custom Meta verification endpoint' do
      get '/webhooks/meta/whatsapp',
          params: {
            'hub.mode' => 'subscribe',
            'hub.challenge' => 'challenge-123',
            'hub.verify_token' => 'owned-verify-token'
          }

      expect(response).to have_http_status(:gone)
      expect(response.parsed_body).to include(
        'error' => 'retired_meta_whatsapp_path',
        'canonical_path' => '/webhooks/whatsapp/:phone_number'
      )
    end
  end

  describe 'POST /webhooks/meta/whatsapp' do
    it 'does not persist messages or call inline AI behavior through the duplicate custom Meta path' do
      payload = {
        object: 'whatsapp_business_account',
        entry: [
          {
            changes: [
              {
                field: 'messages',
                value: {
                  metadata: { phone_number_id: '111222333' },
                  messages: [
                    {
                      from: '255712345678',
                      id: 'wamid.DUPLICATE',
                      timestamp: '1787740800',
                      text: { body: 'Do you offer consulting?' },
                      type: 'text'
                    }
                  ]
                }
              }
            ]
          }
        ]
      }.to_json

      allow(Meta::Whatsapp::InboundWebhookProcessor).to receive(:new)
      allow(AiLeadEmployee::WhatsappAutoReplyService).to receive(:new)

      expect do
        post '/webhooks/meta/whatsapp',
             params: payload,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end.not_to change(Message, :count)

      expect(response).to have_http_status(:gone)
      expect(Meta::Whatsapp::InboundWebhookProcessor).not_to have_received(:new)
      expect(AiLeadEmployee::WhatsappAutoReplyService).not_to have_received(:new)
      expect(response.parsed_body).to include(
        'error' => 'retired_meta_whatsapp_path',
        'canonical_path' => '/webhooks/whatsapp/:phone_number'
      )
    end
  end
end
