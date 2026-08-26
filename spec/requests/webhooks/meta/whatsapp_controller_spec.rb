# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::Meta::WhatsappController', type: :request do
  # rubocop:disable Metrics/MethodLength
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

  def inbound_voice_payload(message_id: 'wamid.HBgLMjU1NzEyMzQ1Njc4FQIAEhggVOICE')
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
                    profile: { name: 'Jane Lead' },
                    wa_id: '255712345678'
                  }
                ],
                messages: [
                  {
                    from: '255712345678',
                    id: message_id,
                    timestamp: '1787740800',
                    audio: { id: 'audio-media-id', mime_type: 'audio/ogg' },
                    type: 'audio'
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end

  def expect_created_owned_records(counts_before)
    expect(
      events: MetaWhatsappWebhookEvent.count,
      contacts: Contact.count,
      contact_inboxes: ContactInbox.count,
      conversations: Conversation.count,
      messages: Message.count
    ).to eq(counts_before.merge(
              events: counts_before[:events] + 1,
              contacts: counts_before[:contacts] + 1,
              contact_inboxes: counts_before[:contact_inboxes] + 1,
              conversations: counts_before[:conversations] + 1,
              messages: counts_before[:messages] + 2
            ))
  end

  def expect_inbound_text_conversation(knowledge_item)
    contact = Contact.last
    conversation = Conversation.last
    message = Message.incoming.last
    reply = Message.outgoing.last

    expect_owned_contact(contact)
    expect_owned_conversation(conversation, contact, knowledge_item)
    expect_owned_incoming_message(message, conversation, contact)
    expect_owned_auto_reply(reply)
  end

  def expect_owned_contact(contact)
    expect(contact).to have_attributes(account: account, name: 'Jane Lead', phone_number: '+255712345678')
  end

  def expect_owned_conversation(conversation, contact, knowledge_item)
    expect(conversation).to have_attributes(account: account, inbox: channel.inbox, contact: contact)
    expect(conversation.additional_attributes['channel']).to eq('meta_whatsapp')
    expect(conversation.reload.additional_attributes['ai_employee_last_decision']).to include(
      'status' => 'answered',
      'sources' => [include('id' => knowledge_item.id, 'source_kind' => 'faq')],
      'qualification' => include(
        'quality' => 'low_qualified',
        'next_question' => 'What budget range have you set aside for this?'
      )
    )
    expect(conversation.contact.lead_qualification.evidence_snapshot).to include('business_type', 'problem')
  end

  def expect_owned_incoming_message(message, conversation, contact)
    expect(message).to have_attributes(
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: contact,
      content: 'Do you offer consulting? I need help getting more leads for my agency.',
      source_id: 'wamid.HBgLMjU1NzEyMzQ1Njc4FQIAEhggMTIz'
    )
    expect(message).to be_incoming
  end

  def expect_owned_auto_reply(reply)
    expect(reply).to have_attributes(
      content: "Yes, we offer consulting for qualified businesses.\n\nWhat budget range have you set aside for this?",
      source_id: 'wamid.AUTO_REPLY'
    )
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
    stub_request(:post, "https://graph.facebook.com/v23.0/#{channel.provider_config['phone_number_id']}/messages")
      .to_return(
        status: 200,
        body: { messages: [{ id: 'wamid.AUTO_REPLY' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
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
      knowledge_item = create(
        :knowledge_item,
        account: account,
        question: 'Do you offer consulting?',
        answer: 'Yes, we offer consulting for qualified businesses.'
      )
      create(:qualification_question, account: account, signal: :problem, prompt: 'What problem are you trying to solve?', position: 1)
      create(:qualification_question, account: account, signal: :budget, prompt: 'What budget range have you set aside for this?', position: 2)
      body = inbound_text_payload(text: 'Do you offer consulting? I need help getting more leads for my agency.').to_json
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

      expect_created_owned_records(counts_before)

      expect(response).to have_http_status(:ok)
      expect_inbound_text_conversation(knowledge_item)
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
      expect(Message.count).to eq(2)
      expect(Conversation.count).to eq(1)
      expect(Contact.last.name).to eq('Jane Lead')
      expect(Message.incoming.last.content).to eq('Do you offer consulting?')
      expect(Message.outgoing.count).to eq(1)
    end

    it 'keeps a voice note as unsupported metadata and asks the lead to send text' do
      body = inbound_voice_payload.to_json

      post '/webhooks/meta/whatsapp',
           params: body,
           headers: {
             'CONTENT_TYPE' => 'application/json',
             'X-Hub-Signature-256' => signature_for(body)
           }

      expect(response).to have_http_status(:ok)
      incoming = Message.incoming.last
      expect(incoming.content).to eq('Unsupported WhatsApp voice note received.')
      expect(incoming.content_attributes).to include(
        'is_unsupported' => true,
        'data' => include(
          'provider_media_type' => 'audio',
          'provider_media_id' => 'audio-media-id',
          'v1_handling' => 'request_text'
        )
      )
      expect(Message.outgoing.last.content).to eq(AiLeadEmployee::WhatsappAutoReplyService::VOICE_NOTE_TEXT_REQUEST)
      expect(Conversation.last.additional_attributes['ai_employee_last_decision']).to include(
        'status' => 'refused',
        'refusal_reason' => 'unsupported_voice_note',
        'qualification' => nil
      )
    end

    it 'does not append a qualification question when the AI Employee cannot answer from approved knowledge' do
      create(:qualification_question, account: account, signal: :problem, prompt: 'What problem are you trying to solve?', position: 1)
      body = inbound_text_payload(text: 'Can you help with something unknown? I need help getting more leads.').to_json

      post '/webhooks/meta/whatsapp',
           params: body,
           headers: {
             'CONTENT_TYPE' => 'application/json',
             'X-Hub-Signature-256' => signature_for(body)
           }

      expect(response).to have_http_status(:ok)
      expect(Message.outgoing.last.content).to eq(AiLeadEmployee::KnowledgeAnswerService::BOUNDARY_RESPONSE)
      expect(Conversation.last.additional_attributes['ai_employee_last_decision']).to include(
        'status' => 'refused',
        'qualification' => include('quality' => 'low_qualified')
      )
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
  # rubocop:enable Metrics/MethodLength
end
