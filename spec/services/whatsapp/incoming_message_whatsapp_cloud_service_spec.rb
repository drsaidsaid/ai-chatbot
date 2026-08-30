require 'rails_helper'

describe Whatsapp::IncomingMessageWhatsappCloudService do
  describe '#perform' do
    after do
      Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
    end

    let!(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false) }
    let(:sender_number) { '2423423243' }
    let(:params) do
      {
        phone_number: whatsapp_channel.phone_number,
        object: 'whatsapp_business_account',
        entry: [{
          changes: [{
            value: {
              contacts: [{ profile: { name: 'Sojan Jose' }, wa_id: sender_number }],
              messages: [{
                from: sender_number,
                image: {
                  id: 'b1c68f38-8734-4ad3-b4a1-ef0c10d683',
                  mime_type: 'image/jpeg',
                  sha256: '29ed500fa64eb55fc19dc4124acb300e5dcca0f822a301ae99944db',
                  caption: 'Check out my product!'
                },
                timestamp: '1664799904', type: 'image'
              }]
            }
          }]
        }]
      }.with_indifferent_access
    end

    context 'when a text message starts a channel-greeted conversation' do
      let(:text_message_id) { 'wamid.CANONICAL.FIRST' }
      let(:text_params) { canonical_text_params(message_id: text_message_id, body: 'Can you help qualify my leads?') }

      before do
        whatsapp_channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome to AI Lead Employee.')
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
            body: { messages: [{ id: 'wamid.GREETING.SENT' }] }.to_json,
            headers: { 'content-type' => 'application/json' }
          )
      end

      it 'persists the lead message before one visible greeting and replays without side effects' do
        perform_enqueued_jobs do
          described_class.new(inbox: whatsapp_channel.inbox, params: text_params).perform
          described_class.new(inbox: whatsapp_channel.inbox, params: text_params).perform
        end

        conversation = whatsapp_channel.inbox.conversations.first
        messages = conversation.messages.chat.order(:created_at, :id).to_a

        expect(whatsapp_channel.account.contacts.find_by!(phone_number: '+2423423243')).to have_attributes(
          name: 'Sojan Jose',
          contact_type: 'lead'
        )
        expect(messages.map(&:content)).to eq(['Can you help qualify my leads?', 'Welcome to AI Lead Employee.'])
        expect(messages.map(&:message_type)).to eq(%w[incoming template])
        expect(Message.where(source_id: text_message_id).count).to eq(1)
        greeting = conversation.messages.template.find_by!(content: 'Welcome to AI Lead Employee.')
        expect(greeting.source_id).to eq('wamid.GREETING.SENT')
        expect(conversation.messages.template.where(content: 'Welcome to AI Lead Employee.').count).to eq(1)
        expect(a_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')).to have_been_made.once
      end
    end

    context 'when Meta sends unsupported media' do
      let(:unsupported_params) do
        canonical_text_params(message_id: 'wamid.UNSUPPORTED.MEDIA', body: nil).tap do |payload|
          message = payload.dig(:entry, 0, :changes, 0, :value, :messages, 0)
          message.delete(:text)
          message[:type] = 'unsupported'
          message[:errors] = [{ code: 131_060, title: 'Unsupported message type' }]
        end
      end

      it 'stores a visible unsupported placeholder without invoking inline AI behavior' do
        allow(AiLeadEmployee::WhatsappAutoReplyService).to receive(:new)

        described_class.new(inbox: whatsapp_channel.inbox, params: unsupported_params).perform

        message = whatsapp_channel.inbox.messages.find_by!(source_id: 'wamid.UNSUPPORTED.MEDIA')
        expect(message).to have_attributes(
          message_type: 'incoming',
          content: I18n.t('conversations.messages.whatsapp.unsupported_message')
        )
        expect(message.content_attributes['is_unsupported']).to be(true)
        expect(AiLeadEmployee::WhatsappAutoReplyService).not_to have_received(:new)
      end
    end

    context 'when Meta sends a delivery status' do
      it 'reconciles the persisted outbound message status by Meta message id' do
        contact = create(:contact, account: whatsapp_channel.account, phone_number: '+2423423243')
        contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '2423423243')
        conversation = create(:conversation, contact: contact, inbox: whatsapp_channel.inbox, contact_inbox: contact_inbox)
        message = create(:message,
                         account: whatsapp_channel.account,
                         inbox: whatsapp_channel.inbox,
                         conversation: conversation,
                         message_type: :outgoing,
                         status: :sent,
                         source_id: 'wamid.OUTBOUND.STATUS')

        described_class.new(inbox: whatsapp_channel.inbox, params: status_params('wamid.OUTBOUND.STATUS', 'read')).perform

        expect(message.reload.status).to eq('read')
      end
    end

    context 'when valid attachment message params' do
      it 'creates appropriate conversations, message and contacts' do
        stub_media_url_request
        stub_sample_png_request
        described_class.new(inbox: whatsapp_channel.inbox, params: params).perform
        expect_conversation_created
        expect_contact_name
        expect_message_content
        expect_message_has_attachment
      end

      it 'increments reauthorization count if fetching attachment fails' do
        stub_request(
          :get,
          whatsapp_channel.media_url('b1c68f38-8734-4ad3-b4a1-ef0c10d683')
        ).to_return(
          status: 401
        )

        described_class.new(inbox: whatsapp_channel.inbox, params: params).perform
        expect(whatsapp_channel.inbox.conversations.count).not_to eq(0)
        expect_contact_name
        expect(whatsapp_channel.inbox.messages.first.content).to eq('Check out my product!')
        expect(whatsapp_channel.inbox.messages.first.attachments.present?).to be false
        expect(whatsapp_channel.authorization_error_count).to eq(1)
      end
    end

    context 'when document attachment includes an accented filename' do
      let(:document_params) do
        {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Sojan Jose' }, wa_id: '2423423243' }],
                messages: [{
                  from: '2423423243',
                  document: {
                    id: 'b1c68f38-8734-4ad3-b4a1-ef0c10d683',
                    mime_type: 'application/pdf',
                    filename: 'Currículum café.pdf',
                    caption: 'My résumé'
                  },
                  timestamp: '1664799904', type: 'document'
                }]
              }
            }]
          }]
        }.with_indifferent_access
      end

      it 'preserves the original filename from the payload' do
        stub_media_url_request
        stub_sample_png_request
        described_class.new(inbox: whatsapp_channel.inbox, params: document_params).perform

        attachment = whatsapp_channel.inbox.messages.first.attachments.first
        expect(attachment.file.filename.to_s).to eq('Currículum café.pdf')
      end
    end

    context 'when a contact submits a WhatsApp Flow response' do
      let(:response_json) do
        {
          flow_token: 'flow-correlation-token',
          rating: 'excellent',
          comments: 'Great support',
          appointment: { day: 'Monday', windows: %w[morning afternoon] }
        }.to_json
      end

      let(:flow_response_params) do
        {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Flow Contact' }, wa_id: '2423423243' }],
                messages: [{
                  context: { from: whatsapp_channel.phone_number, id: 'wamid.original-flow-message' },
                  from: '2423423243',
                  id: 'wamid.flow-response-message',
                  timestamp: '1664799904',
                  type: 'interactive',
                  interactive: {
                    type: 'nfm_reply',
                    nfm_reply: {
                      name: 'flow',
                      body: 'Sent',
                      response_json: response_json
                    }
                  }
                }]
              }
            }]
          }]
        }.with_indifferent_access
      end

      it 'stores the complete response as a visible incoming message' do
        described_class.new(inbox: whatsapp_channel.inbox, params: flow_response_params).perform

        message = whatsapp_channel.inbox.messages.last
        flow_response = message.content_attributes['whatsapp_flow_response']

        expect(message).to have_attributes(
          content: 'Submitted a flow response',
          content_type: 'text',
          message_type: 'incoming',
          source_id: 'wamid.flow-response-message'
        )
        expect(flow_response).to eq(
          'name' => 'flow',
          'body' => 'Sent',
          'response_json' => {
            'flow_token' => 'flow-correlation-token',
            'rating' => 'excellent',
            'comments' => 'Great support',
            'appointment' => { 'day' => 'Monday', 'windows' => %w[morning afternoon] }
          }
        )
        expect(message.webhook_data[:content_attributes]['whatsapp_flow_response']).to eq(flow_response)
      end

      context 'when response_json contains invalid JSON' do
        let(:response_json) { '{invalid-json' }

        it 'stores the raw response without dropping the message' do
          described_class.new(inbox: whatsapp_channel.inbox, params: flow_response_params).perform

          message = whatsapp_channel.inbox.messages.last

          expect(message.content).to eq('Submitted a flow response')
          expect(message.content_attributes.dig('whatsapp_flow_response', 'response_json')).to eq('{invalid-json')
          expect(message.webhook_data[:content_attributes].dig('whatsapp_flow_response', 'response_json')).to eq('{invalid-json')
        end
      end

      context 'when response_json is missing' do
        let(:response_json) { nil }

        it 'stores the flow metadata without dropping the message' do
          described_class.new(inbox: whatsapp_channel.inbox, params: flow_response_params).perform

          message = whatsapp_channel.inbox.messages.last

          expect(message.content).to eq('Submitted a flow response')
          expect(message.content_attributes['whatsapp_flow_response']).to eq(
            'name' => 'flow',
            'body' => 'Sent'
          )
        end
      end
    end

    context 'when invalid attachment message params' do
      let(:error_params) do
        {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Sojan Jose' }, wa_id: sender_number }],
                messages: [{
                  from: sender_number,
                  image: {
                    id: 'b1c68f38-8734-4ad3-b4a1-ef0c10d683',
                    mime_type: 'image/jpeg',
                    sha256: '29ed500fa64eb55fc19dc4124acb300e5dcca0f822a301ae99944db',
                    caption: 'Check out my product!'
                  },
                  errors: [{
                    code: 400,
                    details: 'Last error was: ServerThrottle. Http request error: HTTP response code said error. See logs for details',
                    title: 'Media download failed: Not retrying as download is not retriable at this time'
                  }],
                  timestamp: '1664799904', type: 'image'
                }]
              }
            }]
          }]
        }.with_indifferent_access
      end

      it 'with attachment errors' do
        described_class.new(inbox: whatsapp_channel.inbox, params: error_params).perform
        expect(whatsapp_channel.inbox.conversations.count).not_to eq(0)
        expect_contact_name
        expect(whatsapp_channel.inbox.messages.count).to eq(0)
      end
    end

    context 'when BSUID identifiers are present' do
      it 'creates a contact and conversation when only BSUID is present' do
        bsuid_params = {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{
                  profile: { name: 'Muhsin', username: 'muhsin' },
                  user_id: 'IN.2081978709342942',
                  parent_user_id: 'IN.ENT.9081726354'
                }],
                messages: [{
                  from_user_id: 'IN.2081978709342942',
                  from_parent_user_id: 'IN.ENT.9081726354',
                  id: 'wamid.cloud-bsuid-only-message',
                  text: { body: 'testing bsuid' },
                  timestamp: '1778579582',
                  type: 'text'
                }]
              }
            }]
          }]
        }.with_indifferent_access

        described_class.new(inbox: whatsapp_channel.inbox, params: bsuid_params).perform

        contact_inbox = whatsapp_channel.inbox.contact_inboxes.find_by!(source_id: 'IN.2081978709342942')
        contact = contact_inbox.contact
        parent_contact_inbox = whatsapp_channel.inbox.contact_inboxes.find_by!(source_id: 'IN.ENT.9081726354')

        expect(whatsapp_channel.inbox.conversations.count).to eq(1)
        expect(whatsapp_channel.inbox.messages.first.content).to eq('testing bsuid')
        expect(contact).to have_attributes(name: 'Muhsin', phone_number: nil)
        expect(contact.additional_attributes).to include(
          'social_whatsapp_user_name' => 'muhsin',
          'social_profiles' => { 'whatsapp' => 'muhsin' }
        )
        expect(parent_contact_inbox.contact).to eq(contact)
      end

      it 'links phone and BSUID source ids to the same contact' do
        phone_with_bsuid_params = {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Muhsin' }, wa_id: '919745786257', user_id: 'IN.2081978709342942' }],
                messages: [{
                  from: '919745786257',
                  from_user_id: 'IN.2081978709342942',
                  id: 'wamid.cloud-phone-bsuid-message',
                  text: { body: 'phone and bsuid' },
                  timestamp: '1778579582',
                  type: 'text'
                }]
              }
            }]
          }]
        }.with_indifferent_access
        bsuid_only_params = {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Muhsin' }, user_id: 'IN.2081978709342942' }],
                messages: [{
                  from_user_id: 'IN.2081978709342942',
                  id: 'wamid.cloud-bsuid-follow-up-message',
                  text: { body: 'bsuid only' },
                  timestamp: '1778579583',
                  type: 'text'
                }]
              }
            }]
          }]
        }.with_indifferent_access

        described_class.new(inbox: whatsapp_channel.inbox, params: phone_with_bsuid_params).perform
        contact_inbox = whatsapp_channel.inbox.contact_inboxes.find_by!(source_id: '919745786257')
        bsuid_contact_inbox = whatsapp_channel.inbox.contact_inboxes.find_by!(source_id: 'IN.2081978709342942')

        expect { described_class.new(inbox: whatsapp_channel.inbox, params: bsuid_only_params).perform }.not_to raise_error
        expect(whatsapp_channel.inbox.contact_inboxes.count).to eq(2)
        expect(whatsapp_channel.inbox.messages.pluck(:content)).to contain_exactly('phone and bsuid', 'bsuid only')
        expect(bsuid_contact_inbox.contact).to eq(contact_inbox.contact)
      end
    end

    context 'when invalid params' do
      it 'will not throw error' do
        described_class.new(inbox: whatsapp_channel.inbox, params: { phone_number: whatsapp_channel.phone_number,
                                                                     object: 'whatsapp_business_account', entry: {} }).perform
        expect(whatsapp_channel.inbox.conversations.count).to eq(0)
        expect(Contact.find_by(phone_number: contact_phone_number)).to be_nil
        expect(whatsapp_channel.inbox.messages.count).to eq(0)
      end
    end

    context 'when message contains referral data' do
      let(:referral_params) do
        {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Mom' }, wa_id: '255718573302', user_id: 'TZ.1040042605869930' }],
                messages: [{
                  referral: {
                    source_url: 'https://fb.me/3TYpooaRT',
                    source_id: '52558118838064',
                    source_type: 'ad',
                    body: 'washa data tu',
                    headline: 'Diana Digital',
                    media_type: 'video',
                    video_url: 'https://www.facebook.com/reel/1438165771395493/',
                    thumbnail_url: 'https://scontent.xx.fbcdn.net/sample.jpg',
                    ctwa_clid: 'AfhcQdP2E4A8wWpeb1FqUzUi',
                    welcome_message: {
                      text: 'Hi! Please let us know how we can help you.'
                    }
                  },
                  from: '255718573302',
                  from_user_id: 'TZ.1040042605869930',
                  id: 'wamid.CTWA_REFERRAL_MESSAGE',
                  timestamp: '1780649766',
                  text: { body: 'Hello nielekeze' },
                  type: 'text'
                }]
              }
            }]
          }]
        }.with_indifferent_access
      end

      it 'stores the referral payload in message content attributes' do
        described_class.new(inbox: whatsapp_channel.inbox, params: referral_params).perform

        message = whatsapp_channel.inbox.messages.last
        expect(message.content).to eq('Hello nielekeze')
        expect(message.content_attributes['referral']).to include(
          'source_url' => 'https://fb.me/3TYpooaRT',
          'source_id' => '52558118838064',
          'source_type' => 'ad',
          'body' => 'washa data tu',
          'headline' => 'Diana Digital',
          'media_type' => 'video',
          'video_url' => 'https://www.facebook.com/reel/1438165771395493/',
          'thumbnail_url' => 'https://scontent.xx.fbcdn.net/sample.jpg',
          'ctwa_clid' => 'AfhcQdP2E4A8wWpeb1FqUzUi',
          'welcome_message' => { 'text' => 'Hi! Please let us know how we can help you.' }
        )
      end

      it 'preserves the referral payload when the message contains contacts' do
        contacts_referral_params = referral_params.deep_dup
        parent_message = contacts_referral_params.dig(:entry, 0, :changes, 0, :value, :messages, 0)
        parent_message[:type] = 'contacts'
        parent_message.delete(:text)
        parent_message[:contacts] = [{
          name: {
            formatted_name: 'Diana Digital',
            first_name: 'Diana',
            last_name: 'Digital'
          },
          phones: [{ phone: '+255718573302' }]
        }]

        described_class.new(inbox: whatsapp_channel.inbox, params: contacts_referral_params).perform

        message = whatsapp_channel.inbox.messages.last
        expect(message.content).to eq('Diana Digital')
        expect(message.content_attributes['referral']).to include(
          'source_id' => '52558118838064',
          'headline' => 'Diana Digital',
          'ctwa_clid' => 'AfhcQdP2E4A8wWpeb1FqUzUi'
        )
      end
    end

    context 'when message is a reply (has context)' do
      let(:reply_params) do
        {
          phone_number: whatsapp_channel.phone_number,
          object: 'whatsapp_business_account',
          entry: [{
            changes: [{
              value: {
                contacts: [{ profile: { name: 'Pranav' }, wa_id: '16503071063' }],
                messages: [{
                  context: {
                    from: '16503071063',
                    id: 'wamid.ORIGINAL_MESSAGE_ID'
                  },
                  from: '16503071063',
                  id: 'wamid.REPLY_MESSAGE_ID',
                  timestamp: '1770407829',
                  text: { body: 'This is a reply' },
                  type: 'text'
                }]
              }
            }]
          }]
        }.with_indifferent_access
      end

      context 'when the original message exists in Chatwoot' do
        it 'sets in_reply_to to reference the existing message' do
          # Create a conversation and the original message that will be replied to first
          contact = create(:contact, phone_number: '+16503071063', account: whatsapp_channel.account)
          contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '16503071063')
          conversation = create(:conversation, contact: contact, inbox: whatsapp_channel.inbox, contact_inbox: contact_inbox)

          original_message = create(:message,
                                    conversation: conversation,
                                    source_id: 'wamid.ORIGINAL_MESSAGE_ID',
                                    content: 'Original message')

          described_class.new(inbox: whatsapp_channel.inbox, params: reply_params).perform

          reply_message = whatsapp_channel.inbox.messages.last
          expect(reply_message.content).to eq('This is a reply')
          expect(reply_message.content_attributes['in_reply_to']).to eq(original_message.id)
          expect(reply_message.content_attributes['in_reply_to_external_id']).to eq('wamid.ORIGINAL_MESSAGE_ID')
        end
      end

      context 'when the original message does not exist in Chatwoot' do
        it 'does not set in_reply_to (discards the reply reference)' do
          described_class.new(inbox: whatsapp_channel.inbox, params: reply_params).perform

          reply_message = whatsapp_channel.inbox.messages.last
          expect(reply_message.content).to eq('This is a reply')
          expect(reply_message.content_attributes['in_reply_to']).to be_nil
          expect(reply_message.content_attributes['in_reply_to_external_id']).to be_nil
        end
      end
    end
  end

  # Métodos auxiliares para reduzir o tamanho do exemplo

  def stub_media_url_request
    stub_request(
      :get,
      whatsapp_channel.media_url('b1c68f38-8734-4ad3-b4a1-ef0c10d683')
    ).to_return(
      status: 200,
      body: {
        messaging_product: 'whatsapp',
        url: 'https://chatwoot-assets.local/sample.png',
        mime_type: 'image/jpeg',
        sha256: 'sha256',
        file_size: 'SIZE',
        id: 'b1c68f38-8734-4ad3-b4a1-ef0c10d683'
      }.to_json,
      headers: { 'content-type' => 'application/json' }
    )
  end

  def stub_sample_png_request
    stub_request(:get, 'https://chatwoot-assets.local/sample.png').to_return(
      status: 200,
      body: File.read('spec/assets/sample.png')
    )
  end

  def expect_conversation_created
    expect(whatsapp_channel.inbox.conversations.count).not_to eq(0)
  end

  def expect_contact_name
    expect(contact_from_number&.name).to eq('Sojan Jose')
  end

  def expect_message_content
    expect(whatsapp_channel.inbox.messages.first.content).to eq('Check out my product!')
  end

  def expect_message_has_attachment
    expect(whatsapp_channel.inbox.messages.first.attachments.present?).to be true
  end

  def contact_phone_number
    "+#{sender_number}"
  end

  def contact_from_number
    Contact.find_by(phone_number: contact_phone_number)
  end

  def canonical_text_params(message_id:, body:)
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            contacts: [{ profile: { name: 'Sojan Jose' }, wa_id: sender_number }],
            messages: [{
              from: sender_number,
              id: message_id,
              text: { body: body },
              timestamp: '1787740800',
              type: 'text'
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end

  def status_params(message_id, status)
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          value: {
            statuses: [{
              id: message_id,
              status: status,
              timestamp: '1787740801',
              recipient_id: sender_number
            }]
          }
        }]
      }]
    }.with_indifferent_access
  end
end
