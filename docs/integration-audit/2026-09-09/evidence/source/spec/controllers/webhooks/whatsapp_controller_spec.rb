require 'rails_helper'

RSpec.describe 'Webhooks::WhatsappController', type: :request do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
  let(:client_secret) { 'test-whatsapp-secret' }
  let(:body) { { content: 'hello' }.to_json }

  def signature_for(body, secret = client_secret)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, body)}"
  end

  def post_whatsapp_webhook(path, body, signature: signature_for(body), env: { WHATSAPP_APP_SECRET: client_secret })
    with_modified_env env do
      post path,
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json', 'X-Hub-Signature-256' => signature }
    end
  end

  def post_unsigned_whatsapp_webhook(path, body, env: { WHATSAPP_APP_SECRET: client_secret })
    with_modified_env env do
      post path,
           params: body,
           headers: { 'CONTENT_TYPE' => 'application/json' }
    end
  end

  before do
    InstallationConfig.where(name: 'WHATSAPP_APP_SECRET').delete_all
    GlobalConfig.clear_cache
  end

  after do
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
  end

  describe 'GET /webhooks/verify' do
    it 'returns 401 when valid params are not present' do
      get "/webhooks/whatsapp/#{channel.phone_number}"
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when invalid params' do
      get "/webhooks/whatsapp/#{channel.phone_number}",
          params: { 'hub.challenge' => '123456', 'hub.mode' => 'subscribe', 'hub.verify_token' => 'invalid' }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns challenge when valid params' do
      get "/webhooks/whatsapp/#{channel.phone_number}",
          params: { 'hub.challenge' => '123456', 'hub.mode' => 'subscribe', 'hub.verify_token' => channel.provider_config['webhook_verify_token'] }
      expect(response.body).to include '123456'
    end
  end

  describe 'POST /webhooks/whatsapp/{:phone_number}' do
    it 'persists an inbound message through the canonical webhook job using the payload channel metadata' do
      channel_secret = 'canonical-whatsapp-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!
      allow_retired_whatsapp_services

      payload = canonical_payload(
        channel,
        message_id: 'wamid.CANONICAL.ROUNDTRIP',
        sender_number: '255700111222',
        sender_name: 'Round Trip Lead',
        body: 'Do you offer AI employees?'
      )

      perform_enqueued_jobs do
        post_whatsapp_webhook(
          "/webhooks/whatsapp/#{channel.phone_number}",
          payload,
          signature: signature_for(payload, channel_secret),
          env: {}
        )
      end

      message = channel.inbox.messages.find_by!(source_id: 'wamid.CANONICAL.ROUNDTRIP')
      expect(response).to have_http_status(:success)
      expect(message).to have_attributes(
        account_id: channel.account_id,
        inbox_id: channel.inbox.id,
        message_type: 'incoming',
        content: 'Do you offer AI employees?'
      )
      expect(message.conversation.contact).to have_attributes(
        account_id: channel.account_id,
        name: 'Round Trip Lead',
        phone_number: '+255700111222',
        contact_type: 'lead'
      )
      expect_retired_whatsapp_services_not_called
    end

    it 'uses payload metadata to route a webhook to the matching WhatsApp channel instead of the URL number' do
      url_channel = channel
      payload_channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
      channel_secret = 'payload-channel-secret'
      payload_channel.provider_config = payload_channel.provider_config.merge('app_secret' => channel_secret)
      payload_channel.save!

      payload = canonical_payload(
        payload_channel,
        message_id: 'wamid.PAYLOAD.CHANNEL',
        sender_number: '255700111223',
        sender_name: 'Payload Routed Lead',
        body: 'This should reach the payload channel.'
      )

      perform_enqueued_jobs do
        post_whatsapp_webhook(
          "/webhooks/whatsapp/#{url_channel.phone_number}",
          payload,
          signature: signature_for(payload, channel_secret),
          env: {}
        )
      end

      expect(response).to have_http_status(:success)
      expect(payload_channel.inbox.messages.find_by!(source_id: 'wamid.PAYLOAD.CHANNEL').content).to eq('This should reach the payload channel.')
      expect(url_channel.inbox.messages.find_by(source_id: 'wamid.PAYLOAD.CHANNEL')).to be_nil
    end

    it 'does not process a WhatsApp Cloud payload when no channel matches its phone number id' do
      channel_secret = 'wrong-channel-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!
      payload = canonical_payload(
        channel,
        message_id: 'wamid.INVALID.CHANNEL',
        sender_number: '255700111224',
        sender_name: 'Invalid Channel Lead',
        body: 'This should not persist.'
      )
      parsed_payload = JSON.parse(payload)
      parsed_payload['entry'][0]['changes'][0]['value']['metadata']['phone_number_id'] = 'not-a-channel-id'
      payload = parsed_payload.to_json

      perform_enqueued_jobs do
        post_whatsapp_webhook(
          "/webhooks/whatsapp/#{channel.phone_number}",
          payload,
          signature: signature_for(payload, channel_secret),
          env: {}
        )
      end

      expect(response).to have_http_status(:success)
      expect(Message.find_by(source_id: 'wamid.INVALID.CHANNEL')).to be_nil
    end

    it 'replays a first lead message without duplicating the message, conversation, contact, or sent greeting' do
      channel_secret = 'greeting-channel-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!
      channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome to AI Lead Employee.')
      allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).and_return(true)
      allow_retired_whatsapp_services
      stub_greeting_delivery(sender_number: '255700111225')

      payload = canonical_payload(
        channel,
        message_id: 'wamid.GREETING.ROUNDTRIP',
        sender_number: '255700111225',
        sender_name: 'Greeting Lead',
        body: 'Can you qualify my WhatsApp leads?'
      )

      perform_enqueued_jobs do
        post_whatsapp_webhook("/webhooks/whatsapp/#{channel.phone_number}", payload, signature: signature_for(payload, channel_secret), env: {})
        post_whatsapp_webhook("/webhooks/whatsapp/#{channel.phone_number}", payload, signature: signature_for(payload, channel_secret), env: {})
      end

      conversation = channel.inbox.conversations.first
      messages = conversation.messages.chat.order(:created_at, :id).to_a

      expect(response).to have_http_status(:success)
      expect_replayed_greeting_counts
      expect_replayed_greeting_messages(conversation, messages)
      expect(a_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')).to have_been_made.once
      expect_retired_whatsapp_services_not_called
    end

    it 'stores unsupported media visibly through the canonical route without calling retired AI behavior' do
      channel_secret = 'unsupported-channel-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!
      allow_retired_whatsapp_services
      payload = canonical_payload(
        channel,
        message_id: 'wamid.UNSUPPORTED.ROUNDTRIP',
        sender_number: '255700111226',
        sender_name: 'Unsupported Media Lead',
        body: nil
      )
      parsed_payload = JSON.parse(payload)
      message = parsed_payload['entry'][0]['changes'][0]['value']['messages'][0]
      message.delete('text')
      message['type'] = 'unsupported'
      message['errors'] = [{ code: 131_060, title: 'Unsupported message type' }]
      payload = parsed_payload.to_json

      perform_enqueued_jobs do
        post_whatsapp_webhook(
          "/webhooks/whatsapp/#{channel.phone_number}",
          payload,
          signature: signature_for(payload, channel_secret),
          env: {}
        )
      end

      message = channel.inbox.messages.find_by!(source_id: 'wamid.UNSUPPORTED.ROUNDTRIP')
      expect(response).to have_http_status(:success)
      expect(message.content).to eq(I18n.t('conversations.messages.whatsapp.unsupported_message'))
      expect(message.content_attributes['is_unsupported']).to be(true)
      expect(message.incoming?).to be(true)
      expect_retired_whatsapp_services_not_called
    end

    it 'reconciles delivery status webhooks onto the persisted outbound message through the canonical route' do
      channel_secret = 'status-channel-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!
      allow_retired_whatsapp_services
      contact = create(:contact, account: channel.account, phone_number: '+255700111227')
      contact_inbox = create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700111227')
      conversation = create(:conversation, contact: contact, inbox: channel.inbox, contact_inbox: contact_inbox)
      message = create(:message,
                       account: channel.account,
                       inbox: channel.inbox,
                       conversation: conversation,
                       message_type: :outgoing,
                       status: :sent,
                       source_id: 'wamid.OUTBOUND.ROUNDTRIP')

      payload = status_payload(channel, message_id: 'wamid.OUTBOUND.ROUNDTRIP', status: 'delivered', recipient_number: '255700111227')

      perform_enqueued_jobs do
        post_whatsapp_webhook(
          "/webhooks/whatsapp/#{channel.phone_number}",
          payload,
          signature: signature_for(payload, channel_secret),
          env: {}
        )
      end

      expect(response).to have_http_status(:success)
      expect(message.reload.status).to eq('delivered')
      expect_retired_whatsapp_services_not_called
    end

    it 'calls the whatsapp events job with the params for a valid signature' do
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      post_whatsapp_webhook('/webhooks/whatsapp/123221321', body)
      expect(response).to have_http_status(:success)
    end

    it 'accepts webhook payloads signed with the channel app secret' do
      channel_secret = 'channel-whatsapp-secret'
      channel.provider_config = channel.provider_config.merge('app_secret' => channel_secret)
      channel.save!

      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      channel_body = {
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              metadata: {
                display_phone_number: channel.phone_number.delete_prefix('+'),
                phone_number_id: channel.provider_config['phone_number_id']
              }
            }
          }]
        }]
      }.to_json

      post_whatsapp_webhook(
        "/webhooks/whatsapp/#{channel.phone_number}",
        channel_body,
        signature: signature_for(channel_body, channel_secret),
        env: {}
      )

      expect(response).to have_http_status(:success)
    end

    it 'skips signature validation for 360dialog channels' do
      dialog_channel = create(:channel_whatsapp, provider: 'default', sync_templates: false, validate_provider_config: false)
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      post_unsigned_whatsapp_webhook("/webhooks/whatsapp/#{dialog_channel.phone_number}", body)

      expect(response).to have_http_status(:success)
    end

    it 'skips signature validation for manual whatsapp cloud channels without an app secret' do
      channel.update!(
        provider_config: channel.provider_config.except('app_secret', 'app_secret_key', 'api_secret', 'client_secret', 'source')
      )
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
      expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      channel_body = {
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              metadata: {
                display_phone_number: channel.phone_number.delete_prefix('+'),
                phone_number_id: channel.provider_config['phone_number_id']
              }
            }
          }]
        }]
      }.to_json

      post_unsigned_whatsapp_webhook("/webhooks/whatsapp/#{channel.phone_number}", channel_body)

      expect(response).to have_http_status(:success)
    end

    it 'returns unauthorized when signature is missing' do
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      with_modified_env WHATSAPP_APP_SECRET: client_secret do
        post '/webhooks/whatsapp/123221321',
             params: body,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end

      expect(response).to have_http_status(:unauthorized)
      expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
    end

    it 'returns unauthorized when signature is invalid' do
      allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)

      post_whatsapp_webhook('/webhooks/whatsapp/123221321', body, signature: 'sha256=invalid-signature')

      expect(response).to have_http_status(:unauthorized)
      expect(Webhooks::WhatsappEventsJob).not_to have_received(:perform_later)
    end

    context 'when phone number is in inactive list' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('INACTIVE_WHATSAPP_NUMBERS').and_return('+1234567890,+9876543210')
      end

      it 'returns service unavailable for inactive phone number in URL params' do
        allow(Rails.logger).to receive(:warn)
        expect(Rails.logger).to receive(:warn).with('Rejected webhook for inactive WhatsApp number: +1234567890')

        post_whatsapp_webhook('/webhooks/whatsapp/+1234567890', body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body['error']).to eq('Inactive WhatsApp number')
      end
    end

    context 'when INACTIVE_WHATSAPP_NUMBERS config is not set' do
      before do
        allow(GlobalConfig).to receive(:get_value).with('INACTIVE_WHATSAPP_NUMBERS').and_return(nil)
      end

      it 'processes the webhook normally' do
        allow(Webhooks::WhatsappEventsJob).to receive(:perform_later)
        expect(Webhooks::WhatsappEventsJob).to receive(:perform_later)

        post_whatsapp_webhook('/webhooks/whatsapp/+1234567890', body)
        expect(response).to have_http_status(:success)
      end
    end
  end

  def canonical_payload(channel, message_id:, sender_number:, sender_name:, body:)
    canonical_webhook_payload(
      channel,
      contacts: [{ profile: { name: sender_name }, wa_id: sender_number }],
      messages: [{ from: sender_number, id: message_id, timestamp: '1787740800', text: { body: body }, type: 'text' }]
    ).to_json
  end

  def status_payload(channel, message_id:, status:, recipient_number:)
    canonical_webhook_payload(
      channel,
      statuses: [{ id: message_id, status: status, timestamp: '1787740801', recipient_id: recipient_number }]
    ).to_json
  end

  def canonical_webhook_payload(channel, value)
    {
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          field: 'messages',
          value: {
            messaging_product: 'whatsapp',
            metadata: channel_metadata(channel)
          }.merge(value)
        }]
      }]
    }
  end

  def channel_metadata(channel)
    {
      display_phone_number: channel.phone_number.delete_prefix('+'),
      phone_number_id: channel.provider_config['phone_number_id']
    }
  end

  def stub_greeting_delivery(sender_number:)
    stub_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
      .with(
        body: {
          messaging_product: 'whatsapp',
          context: nil,
          to: sender_number,
          text: { body: 'Welcome to AI Lead Employee.' },
          type: 'text'
        }.to_json
      )
      .to_return(
        status: 200,
        body: { messages: [{ id: 'wamid.GREETING.ROUNDTRIP.SENT' }] }.to_json,
        headers: { 'content-type' => 'application/json' }
      )
  end

  def allow_retired_whatsapp_services
    allow(Meta::Whatsapp::InboundWebhookProcessor).to receive(:new)
    allow(Meta::Whatsapp::OutboundMessageSender).to receive(:new)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
    allow(AiLeadEmployee::WhatsappAutoReplyService).to receive(:new)
  end

  def expect_retired_whatsapp_services_not_called
    expect(Meta::Whatsapp::InboundWebhookProcessor).not_to have_received(:new)
    expect(Meta::Whatsapp::OutboundMessageSender).not_to have_received(:new)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
    expect(AiLeadEmployee::WhatsappAutoReplyService).not_to have_received(:new)
  end

  def expect_replayed_greeting_counts
    expect(channel.account.contacts.where(phone_number: '+255700111225').count).to eq(1)
    expect(channel.inbox.contact_inboxes.where(source_id: '255700111225').count).to eq(1)
    expect(channel.inbox.conversations.count).to eq(1)
  end

  def expect_replayed_greeting_messages(conversation, messages)
    expect_replayed_greeting_sequence(messages)
    expect(conversation.messages.template.first.source_id).to eq('wamid.GREETING.ROUNDTRIP.SENT')
    expect_orchestration_outbox(conversation)
  end

  def expect_replayed_greeting_sequence(messages)
    expect(messages.map(&:content)).to eq([
                                            'Can you qualify my WhatsApp leads?',
                                            'Welcome to AI Lead Employee.'
                                          ])
    expect(messages.map(&:message_type)).to eq(%w[incoming template])
  end

  def expect_orchestration_outbox(conversation)
    lead_message = conversation.messages.incoming.find_by!(source_id: 'wamid.GREETING.ROUNDTRIP')
    expect(conversation.messages.outgoing.count).to eq(0)
    expect(OutboxEvent.where(event_type: AiLeadEmployee::Orchestration::DecisionPlaceholder::OUTBOX_EVENT_TYPE).count).to eq(0)
    expect(HumanReviewRequest.where(conversation: conversation, lead_message: lead_message, reason: :no_approved_knowledge).count).to eq(1)
  end
end
