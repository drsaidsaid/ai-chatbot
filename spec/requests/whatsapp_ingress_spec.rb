require 'rails_helper'

RSpec.describe 'Verified WhatsApp receiving', type: :request do
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              provider_config: { 'source' => 'embedded_signup', 'app_secret' => 'r03-signing-secret' })
  end

  def envelope_for(connection, id: 'wamid.R03.ONE', from: '255711111111', name: 'Amina', body: 'Habari')
    {
      object: 'whatsapp_business_account', entry: [{ id: connection.provider_config['business_account_id'], changes: [{
        field: 'messages', value: {
          metadata: { phone_number_id: connection.provider_config['phone_number_id'],
                      display_phone_number: connection.phone_number.delete_prefix('+') },
          contacts: [{ wa_id: from, profile: { name: name } }],
          messages: [{ id: id, from: from, timestamp: '1789000000', type: 'text', text: { body: body } }]
        }
      }] }]
    }
  end

  def deliver(payload, secret: 'r03-signing-secret', signature: nil)
    raw = payload.is_a?(String) ? payload : payload.to_json
    signature ||= "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, raw)}" if secret
    request_headers = { 'CONTENT_TYPE' => 'application/json' }
    request_headers['X-Hub-Signature-256'] = signature if signature
    post "/webhooks/whatsapp/#{channel.phone_number}", params: raw, headers: request_headers
  end

  def status_envelope(message, status, timestamp, **attributes)
    payload = envelope_for(channel)
    value = payload.dig(:entry, 0, :changes, 0, :value)
    value.delete(:messages)
    value[:statuses] = [{ id: message.source_id, status: status, timestamp: timestamp, **attributes }]
    payload
  end

  it 'rejects unsigned manual setup even when no signing secret was configured' do
    # Simulate a pre-existing incomplete installation, bypassing configuration writers.
    channel.update_columns(provider_config: channel[:provider_config].merge('source' => 'manual'), provider_secrets: nil) # rubocop:disable Rails/SkipsModelValidations
    channel.reload
    deliver(envelope_for(channel), secret: nil)

    expect(response).to have_http_status(:unauthorized)
    expect(channel.inbox.messages).to be_empty
  end

  it 'acknowledges a signed envelope only after its exact receipt and routing are durable' do
    raw = envelope_for(channel).to_json
    deliver(raw)

    expect(response).to have_http_status(:ok)
    receipt = Whatsapp::WebhookReceipt.find(response.parsed_body.fetch('receipt_id'))
    expect(receipt.raw_body).to eq(raw)
    expect(receipt.verified_routes).to contain_exactly(
      'entry' => 0, 'change' => 0, 'channel_id' => channel.id, 'account_id' => channel.account_id, 'inbox_id' => channel.inbox.id
    )
    expect(channel.inbox.messages).to be_empty

    deliver(raw)
    expect(response.parsed_body.fetch('receipt_id')).to eq(receipt.id)
    expect(Whatsapp::WebhookReceipt.count).to eq(1)
  end

  it 'persists every entry, change and sender in the correct Business Account' do
    other = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                                      provider_config: { 'source' => 'embedded_signup', 'app_secret' => 'r03-signing-secret' })
    payload = envelope_for(channel)
    second = envelope_for(channel, id: 'wamid.R03.TWO', from: '255722222222', name: 'Baraka', body: 'Bei?')
    value = payload.dig(:entry, 0, :changes, 0, :value)
    value[:contacts] += second.dig(:entry, 0, :changes, 0, :value, :contacts)
    value[:messages] += second.dig(:entry, 0, :changes, 0, :value, :messages)
    third = envelope_for(channel, id: 'wamid.R03.THREE', body: 'Asante')
    payload[:entry][0][:changes] += third[:entry][0][:changes]
    fourth = envelope_for(other, id: 'wamid.R03.FOUR', from: '255733333333', name: 'Chiku', body: 'Hello')
    payload[:entry] += fourth[:entry]

    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(payload) }

    expect(response).to have_http_status(:ok)
    expect(channel.inbox.messages.incoming.order(:id).map { |message| [message.sender.name, message.content] })
      .to eq([['Amina', 'Habari'], ['Baraka', 'Bei?'], ['Amina', 'Asante']])
    expect(other.inbox.messages.incoming.map { |message| [message.sender.name, message.content] }).to eq([%w[Chiku Hello]])
    expect(channel.inbox.conversations.count).to eq(2)
    expect(other.inbox.conversations.count).to eq(1)
  end

  it 'retains receipts during a queue outage and recovers without a second logical message' do
    channel
    adapter_class = Class.new do
      def enqueue(*)
        raise IOError, 'synthetic queue outage'
      end

      alias_method :enqueue_at, :enqueue
    end
    stub_const('UnavailableQueueAdapter', adapter_class)
    unavailable_queue = adapter_class.new
    previous_adapter = Webhooks::WhatsappEventsJob.queue_adapter
    Webhooks::WhatsappEventsJob.queue_adapter = unavailable_queue
    deliver(envelope_for(channel))
    expect(response).to have_http_status(:ok)
    receipt = Whatsapp::WebhookReceipt.find(response.parsed_body.fetch('receipt_id'))
    expect(receipt.error_code).to eq('queue_unavailable')

    Webhooks::WhatsappEventsJob.queue_adapter = previous_adapter
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { Whatsapp::RecoveryJob.perform_now }
    expect(channel.inbox.messages.incoming.pluck(:content)).to eq(['Habari'])

    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(envelope_for(channel)) }
    expect(channel.inbox.messages.incoming.pluck(:content)).to eq(['Habari'])
  ensure
    Webhooks::WhatsappEventsJob.queue_adapter = previous_adapter
  end

  it 'retains every delivery update without regressing read or delivered messages' do
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(envelope_for(channel)) }
    conversation = channel.inbox.conversations.first
    read_message = create(:message, conversation: conversation, inbox: channel.inbox, account: channel.account,
                                    message_type: :outgoing, status: :read, source_id: 'wamid.R03.READ')
    sent_message = create(:message, conversation: conversation, inbox: channel.inbox, account: channel.account,
                                    message_type: :outgoing, status: :sent, source_id: 'wamid.R03.DELIVERED')
    payload = envelope_for(channel)
    value = payload.dig(:entry, 0, :changes, 0, :value)
    value.delete(:messages)
    value[:statuses] = [
      { id: read_message.source_id, status: 'sent', timestamp: '1789000001' },
      { id: sent_message.source_id, status: 'delivered', timestamp: '1789000002' },
      { id: read_message.source_id, status: 'failed', timestamp: '1789000003', errors: [{ code: 190, title: 'Unsafe provider detail' }] }
    ]

    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(payload) }

    expect(read_message.reload.status).to eq('read')
    expect(sent_message.reload.status).to eq('delivered')
    expect(read_message.external_error.to_s).not_to include('Unsafe provider detail')
    expect(Whatsapp::WebhookEvent.where(kind: 'statuses').count).to eq(3)
  end

  it 'applies the same monotonic delivery projection to old queued work after verified receipt processing' do
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(envelope_for(channel)) }
    %w[delivered read sent].each do |status|
      message = create(:message, conversation: channel.inbox.conversations.first, inbox: channel.inbox, account: channel.account,
                                 message_type: :outgoing, status: :sent, source_id: "wamid.R03.LEGACY.#{status}")
      perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(status_envelope(message, status, '1789000020')) }

      legacy = status_envelope(message, 'sent', '1789000010', recipient_user_id: "TZ.R03#{status}")
      Webhooks::WhatsappEventsJob.perform_now(legacy.with_indifferent_access)
      expect(message.reload.status).to eq(status)
      expect(channel.inbox.contact_inboxes.find_by!(source_id: "TZ.R03#{status}").contact).to eq(message.conversation.contact)

      legacy = status_envelope(message, 'failed', '1789000010', errors: [{ code: 190, title: 'Unsafe provider secret' }])
      Webhooks::WhatsappEventsJob.perform_now(legacy.with_indifferent_access)
      expect(message.reload.status).to eq(status)
      expect(message.content_attributes.to_json).not_to include('Unsafe provider secret')
    end
  end

  it 'projects legacy failures with safe errors and provider-time ordering' do
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(envelope_for(channel)) }
    message = create(:message, conversation: channel.inbox.conversations.first, inbox: channel.inbox, account: channel.account,
                               message_type: :outgoing, status: :sent, source_id: 'wamid.R03.LEGACY.FAILURE')
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(status_envelope(message, 'sent', '1789000020')) }

    legacy = status_envelope(message, 'failed', '1789000030', errors: [{ code: 190, title: 'Unsafe provider secret' }])
    Webhooks::WhatsappEventsJob.perform_now(legacy.with_indifferent_access)
    expect(message.reload).to have_attributes(
      status: 'failed', external_error: 'WhatsApp could not deliver this message. Check the connection before retrying.',
      content_attributes: include('whatsapp_delivery_error_code' => '190', 'whatsapp_delivery_timestamp' => 1_789_000_030)
    )
    Webhooks::WhatsappEventsJob.perform_now(status_envelope(message, 'sent', '1789000020').with_indifferent_access)
    expect(message.reload.status).to eq('failed')
    Webhooks::WhatsappEventsJob.perform_now(status_envelope(message, 'sent', '1789000040').with_indifferent_access)
    expect(message.reload).to have_attributes(status: 'sent', external_error: nil)
    expect(message.content_attributes['whatsapp_delivery_error_code']).to be_nil
  end

  it 'rejects an entire batch signed for only one of its Business Accounts' do
    other = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                                      provider_config: { 'app_secret' => 'different-app-secret' })
    payload = envelope_for(channel)
    payload[:entry] += envelope_for(other)[:entry]
    deliver(payload)
    expect(response).to have_http_status(:unauthorized)
    expect(Whatsapp::WebhookReceipt.count).to eq(0)
  end

  it 'rejects modified raw bytes, missing signatures and wrong signatures before accepting a receipt' do
    raw = envelope_for(channel).to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'r03-signing-secret', raw)}"
    deliver("#{raw} ", signature: signature)
    expect(response).to have_http_status(:unauthorized)
    deliver(raw, secret: nil)
    expect(response).to have_http_status(:unauthorized)
    deliver(raw, secret: 'wrong-secret')
    expect(response).to have_http_status(:unauthorized)
    expect(Whatsapp::WebhookReceipt.count).to eq(0)
  end

  it 'correlates an early delivery status after the outgoing provider ID becomes available' do
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(envelope_for(channel)) }
    payload = envelope_for(channel)
    value = payload.dig(:entry, 0, :changes, 0, :value)
    value.delete(:messages)
    value[:statuses] = [{ id: 'wamid.R03.LATE', status: 'read', timestamp: '1789000005' }]
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(payload) }
    event = Whatsapp::WebhookEvent.find_by!(provider_message_id: 'wamid.R03.LATE')
    expect(event.state).to eq('awaiting_message')

    message = create(:message, conversation: channel.inbox.conversations.first, inbox: channel.inbox, account: channel.account,
                               message_type: :outgoing, status: :sent, source_id: 'wamid.R03.LATE')
    travel 61.seconds do
      perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { Whatsapp::RecoveryJob.perform_now }
    end
    expect(message.reload.status).to eq('read')
    expect(event.reload.state).to eq('processed')
  end

  it 'keeps a temporary media failure retryable instead of accepting a message without its attachment' do
    payload = envelope_for(channel, id: 'wamid.R03.MEDIA')
    message = payload.dig(:entry, 0, :changes, 0, :value, :messages, 0)
    message.delete(:text)
    message[:type] = 'image'
    message[:image] = { id: 'media3', caption: 'A photo' }
    stub_request(:get, 'https://graph.facebook.com/v13.0/media3').to_return(status: 503)
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(payload) }

    expect(channel.inbox.messages.incoming.count).to eq(0)
    expect(Whatsapp::WebhookEvent.find_by!(provider_message_id: 'wamid.R03.MEDIA').state).to eq('failed')
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jZV8AAAAASUVORK5CYII=')
    stub_request(:get, 'https://graph.facebook.com/v13.0/media3')
      .to_return(status: 200, body: { url: 'https://media.example.test/image.png' }.to_json, headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://media.example.test/image.png')
      .to_return(status: 200, body: png, headers: { 'Content-Type' => 'image/png' })
    travel 61.seconds do
      perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { Whatsapp::RecoveryJob.perform_now }
    end
    stored = channel.inbox.messages.incoming.find_by!(source_id: 'wamid.R03.MEDIA')
    expect(stored.attachments.first.file.download).to eq(png)
    expect(channel.inbox.messages.incoming.count).to eq(1)
  end

  it 'rejects malformed event arrays before acknowledging an unprocessable receipt' do
    payload = envelope_for(channel)
    payload.dig(:entry, 0, :changes, 0, :value)[:messages] = ['invalid']
    deliver(payload)
    expect(response).to have_http_status(:bad_request)
    expect(Whatsapp::WebhookReceipt.count).to eq(0)
  end

  it 'retains recipient identifier synchronization when projecting a delivery update' do
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(envelope_for(channel)) }
    message = create(:message, conversation: channel.inbox.conversations.first, inbox: channel.inbox, account: channel.account,
                               message_type: :outgoing, status: :sent, source_id: 'wamid.R03.IDENTIFIER')
    payload = envelope_for(channel)
    value = payload.dig(:entry, 0, :changes, 0, :value)
    value.delete(:messages)
    value[:statuses] = [{ id: message.source_id, status: 'read', timestamp: '1789000005', recipient_user_id: 'TZ.R03BSUID' }]
    perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { deliver(payload) }

    expect(message.reload.status).to eq('read')
    expect(channel.inbox.contact_inboxes.find_by!(source_id: 'TZ.R03BSUID').contact).to eq(message.conversation.contact)
  end

  it 'recovers a newer pending message ahead of old delivery updates that are retried repeatedly' do
    routes = [{ channel_id: channel.id, account_id: channel.account_id, inbox_id: channel.inbox.id }]
    100.times do |index|
      saved = Whatsapp::WebhookReceipt.create!(raw_body: '{}', body_digest: "old-#{index}", verified_routes: routes, expanded_at: 2.days.ago)
      saved.events.create!(channel: channel, account: channel.account, inbox: channel.inbox,
                           event_key: "old-#{index}", kind: 'statuses', payload: { status: 'read' },
                           state: :awaiting_message, next_attempt_at: 1.second.ago, created_at: 2.days.ago)
    end
    pending = Whatsapp::WebhookReceipt.create!(raw_body: '{}', body_digest: 'pending', verified_routes: routes, expanded_at: 1.hour.ago)
    pending.events.create!(channel: channel, account: channel.account, inbox: channel.inbox,
                           event_key: 'pending', kind: 'messages', payload: { body: 'Waiting customer' }, created_at: 1.hour.ago)

    expect { Whatsapp::RecoveryJob.perform_now }.to have_enqueued_job(Webhooks::WhatsappEventsJob).with(pending.id)
  end
end
