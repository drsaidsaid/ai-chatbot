# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::Meta::WhatsappController', type: :request do
  # rubocop:disable Metrics/MethodLength, RSpec/MultipleExpectations
  let(:verify_token) { 'owned-verify-token' }
  let(:app_secret) { 'owned-app-secret' }
  let(:account) { create(:account) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: {
        'api_key' => 'test-key',
        'phone_number_id' => '111222333',
        'business_account_id' => '444555666',
        'source' => 'embedded_signup'
      }
    )
  end

  def signature_for(body)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', app_secret, body)}"
  end

  def inbound_text_payload(message_id: 'wamid.HBgLMjU1NzEyMzQ1Njc4FQIAEhggMTIz', text: 'Do you offer consulting?', name: 'Jane Lead')
    {
      object: 'whatsapp_business_account',
      entry: [
        {
          id: '444555666',
          changes: [
            {
              field: 'messages',
              value: {
                messaging_product: 'whatsapp',
                metadata: {
                  display_phone_number: '15551234567',
                  phone_number_id: channel.provider_config['phone_number_id']
                },
                contacts: [
                  {
                    profile: { name: name },
                    wa_id: '255712345678'
                  }
                ],
                messages: [
                  {
                    from: '255712345678',
                    id: message_id,
                    timestamp: '1787740800',
                    text: { body: text },
                    type: 'text'
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end

  def status_payload(message_id: 'wamid.HBgLMjU1NzEyMzQ1Njc4FQIAEhggOUT', status: 'delivered')
    {
      object: 'whatsapp_business_account',
      entry: [
        {
          id: '444555666',
          changes: [
            {
              field: 'messages',
              value: {
                messaging_product: 'whatsapp',
                metadata: {
                  display_phone_number: '15551234567',
                  phone_number_id: channel.provider_config['phone_number_id']
                },
                statuses: [
                  {
                    id: message_id,
                    status: status,
                    timestamp: '1787740900',
                    recipient_id: '255712345678'
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end

  around do |example|
    with_modified_env(
      META_WEBHOOK_VERIFY_TOKEN: verify_token,
      META_APP_SECRET: app_secret,
      &example
    )
  end

  before do
    InstallationConfig.where(name: %w[META_WEBHOOK_VERIFY_TOKEN META_APP_SECRET]).delete_all
    GlobalConfig.clear_cache
  end

  describe 'GET /webhooks/meta/whatsapp' do
    it 'returns the challenge for the owned Meta verify token' do
      get '/webhooks/meta/whatsapp',
          params: {
            'hub.mode' => 'subscribe',
            'hub.challenge' => 'challenge-123',
            'hub.verify_token' => verify_token
          }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('challenge-123')
    end

    it 'rejects an invalid verify token' do
      get '/webhooks/meta/whatsapp',
          params: {
            'hub.mode' => 'subscribe',
            'hub.challenge' => 'challenge-123',
            'hub.verify_token' => 'wrong-token'
          }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /webhooks/meta/whatsapp' do
    it 'persists a signed inbound Meta text message in the owned inbox' do
      body = inbound_text_payload.to_json
      counts_before = {
        events: MetaWhatsappWebhookEvent.count,
        contacts: Contact.count,
        contact_inboxes: ContactInbox.count,
        conversations: Conversation.count,
        messages: Message.count
      }

      post '/webhooks/meta/whatsapp',
           params: body,
           headers: {
             'CONTENT_TYPE' => 'application/json',
             'X-Hub-Signature-256' => signature_for(body)
           }

      expect(
        events: MetaWhatsappWebhookEvent.count,
        contacts: Contact.count,
        contact_inboxes: ContactInbox.count,
        conversations: Conversation.count,
        messages: Message.count
      ).to eq(counts_before.transform_values { |count| count + 1 })

      expect(response).to have_http_status(:ok)

      contact = Contact.last
      expect(contact.account).to eq(account)
      expect(contact.name).to eq('Jane Lead')
      expect(contact.phone_number).to eq('+255712345678')

      conversation = Conversation.last
      expect(conversation.account).to eq(account)
      expect(conversation.inbox).to eq(channel.inbox)
      expect(conversation.contact).to eq(contact)
      expect(conversation.additional_attributes['channel']).to eq('meta_whatsapp')

      message = Message.last
      expect(message.account).to eq(account)
      expect(message.inbox).to eq(channel.inbox)
      expect(message.conversation).to eq(conversation)
      expect(message.sender).to eq(contact)
      expect(message).to be_incoming
      expect(message.content).to eq('Do you offer consulting?')
      expect(message.source_id).to eq('wamid.HBgLMjU1NzEyMzQ1Njc4FQIAEhggMTIz')
    end

    it 'does not duplicate records when Meta replays the same message event' do
      body = inbound_text_payload.to_json
      replay_body = inbound_text_payload(text: 'Changed replay text', name: 'Changed Replay Name').to_json
      headers = {
        'CONTENT_TYPE' => 'application/json',
        'X-Hub-Signature-256' => signature_for(body)
      }
      replay_headers = {
        'CONTENT_TYPE' => 'application/json',
        'X-Hub-Signature-256' => signature_for(replay_body)
      }

      post '/webhooks/meta/whatsapp', params: body, headers: headers
      post '/webhooks/meta/whatsapp', params: replay_body, headers: replay_headers

      expect(response).to have_http_status(:ok)
      expect(MetaWhatsappWebhookEvent.count).to eq(1)
      expect(Message.count).to eq(1)
      expect(Conversation.count).to eq(1)
      expect(Contact.last.name).to eq('Jane Lead')
      expect(Message.last.content).to eq('Do you offer consulting?')
    end

    it 'rejects unsigned payloads before persistence' do
      body = inbound_text_payload.to_json

      expect do
        post '/webhooks/meta/whatsapp',
             params: body,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end.not_to change(MetaWhatsappWebhookEvent, :count)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'reconciles Meta delivery statuses onto existing outbound messages' do
      conversation = create(:conversation, account: account, inbox: channel.inbox)
      message = create(
        :message,
        account: account,
        inbox: channel.inbox,
        conversation: conversation,
        message_type: :outgoing,
        status: :sent,
        source_id: 'wamid.HBgLMjU1NzEyMzQ1Njc4FQIAEhggOUT'
      )
      body = status_payload.to_json

      expect do
        post '/webhooks/meta/whatsapp',
             params: body,
             headers: {
               'CONTENT_TYPE' => 'application/json',
               'X-Hub-Signature-256' => signature_for(body)
             }
      end.to change(MetaWhatsappWebhookEvent, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(message.reload).to be_delivered
    end
  end
  # rubocop:enable Metrics/MethodLength, RSpec/MultipleExpectations
end
