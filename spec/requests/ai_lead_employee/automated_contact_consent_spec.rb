# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Automated Contact Consent', type: :request do
  let(:signing_secret) { 'r05-signing-secret' }
  let(:channel) do
    create(
      :channel_whatsapp,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: { 'source' => 'embedded_signup', 'app_secret' => signing_secret }
    )
  end
  let(:admin) { create(:user, account: channel.account, role: :administrator) }

  before do
    channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome. How can we help?')
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).and_return(true)
  end

  after do
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it 'records a signed English stop before any greeting or AI work', :aggregate_failures do
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
    post_signed_stop(body: 'Please stop messaging me.', message_id: 'wamid.R05.STOP.EN')

    expect(response).to have_http_status(:ok)
    receipt_id = response.parsed_body.fetch('receipt_id')

    Webhooks::WhatsappEventsJob.perform_now(receipt_id)

    get "/api/v1/accounts/#{channel.account_id}/leads", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    lead = response.parsed_body.fetch('selected_lead')
    expect(lead.dig('detail', 'automated_contact_consent')).to include(
      'state' => 'withdrawn',
      'purpose' => 'automated_contact',
      'reason' => 'lead_requested_stop',
      'evidence' => include(
        'source_message_id' => be_a(Integer),
        'source_conversation_id' => lead.dig('conversation', 'id'),
        'text' => 'Please stop messaging me.',
        'occurred_at' => Time.zone.at(1_789_000_000).iso8601,
        'recognizer_version' => be_present
      )
    )
    evidence = LeadConsentEvent.find(lead.dig('detail', 'automated_contact_consent', 'evidence', 'id'))
    expect(evidence.update(evidence_text: 'rewritten')).to be(false)
    expect(evidence.reload.evidence_text).to eq('Please stop messaging me.')

    get "/api/v1/accounts/#{channel.account_id}/conversations/#{lead.dig('conversation', 'display_id')}/messages",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('payload').map { |message| [message['message_type'], message['content']] })
      .to eq([[0, 'Please stop messaging me.']])
    expect(provider_request).not_to have_been_requested
  end

  it 'keeps a mixed stop and support request visible without automated acknowledgement', :aggregate_failures do
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
    content = 'Please stop messaging me. I need a human to help with a refund.'
    post_signed_stop(body: content, message_id: 'wamid.R05.STOP.SUPPORT', sender: '255700000109')

    Webhooks::WhatsappEventsJob.perform_now(response.parsed_body.fetch('receipt_id'))
    lead = lead_for('255700000109', headers: admin.create_new_auth_token)
    conversation = channel.account.conversations.find_by!(display_id: lead.dig('conversation', 'display_id'))
    get "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages",
        headers: admin.create_new_auth_token,
        as: :json

    expect(lead.dig('detail', 'automated_contact_consent')).to include('state' => 'withdrawn')
    expect(response.parsed_body.fetch('payload').map { |message| [message['message_type'], message['content']] })
      .to eq([[0, content]])
    expect(conversation.ai_orchestration_intents).to be_empty
    expect(conversation.messages.outgoing).to be_empty
    expect(provider_request).not_to have_been_requested
  end

  it 'distinguishes English Swahili and mixed withdrawal from negated or quoted stop phrases' do
    channel.inbox.update!(greeting_enabled: false)
    examples = {
      '255700000111' => ['Please stop messaging me.', 'withdrawn'],
      '255700000112' => ['Tafadhali usinitumie ujumbe tena.', 'withdrawn'],
      '255700000113' => ['Please usinitumie messages tena.', 'withdrawn'],
      '255700000114' => ["I don't want to stop receiving messages.", 'unknown'],
      '255700000115' => ['What does "please stop messaging me" mean?', 'unknown'],
      '255700000116' => ['Stop losing leads for my business.', 'unknown'],
      '255700000117' => ['What does please stop messaging me mean?', 'unknown'],
      '255700000118' => ["What does 'please stop messaging me' mean?", 'unknown'],
      '255700000119' => ['Could you explain please stop messaging me?', 'unknown'],
      '255700000120' => ['Does stop messaging me mean unsubscribe?', 'unknown'],
      '255700000121' => ['Please stop messaging me. Can you confirm?', 'withdrawn']
    }

    examples.each_with_index do |(sender, (body, _state)), index|
      post_signed_stop(body: body, message_id: "wamid.R05.CORPUS.#{index}", sender: sender)
      Webhooks::WhatsappEventsJob.perform_now(response.parsed_body.fetch('receipt_id'))
    end

    get "/api/v1/accounts/#{channel.account_id}/leads",
        headers: admin.create_new_auth_token,
        params: { per_page: 100 },
        as: :json

    expect(response).to have_http_status(:ok)
    states_by_phone = response.parsed_body.fetch('leads').to_h do |lead|
      [lead.fetch('phone_number').delete_prefix('+'), lead.dig('detail', 'automated_contact_consent', 'state')]
    end
    expect(states_by_phone.slice(*examples.keys)).to eq(examples.transform_values(&:last))
  end

  it 'records administrator re-consent only from a newer verified explicit inbound message without sending' do
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
    sender = '255700000121'
    process_signed_message(body: 'Please stop messaging me.', message_id: 'wamid.R05.RECONSENT.STOP', sender: sender)

    process_signed_message(
      body: 'Yes, you can message me again.',
      message_id: 'wamid.R05.RECONSENT.GRANT',
      sender: sender,
      timestamp: '1789000060'
    )
    stopped_lead = lead_for(sender, headers: admin.create_new_auth_token)
    candidate = stopped_lead.dig('detail', 'automated_contact_consent', 'reconsent_candidate')

    expect(candidate).to include(
      'source_message_id' => be_a(Integer),
      'expected_event_id' => stopped_lead.dig('detail', 'automated_contact_consent', 'evidence', 'id'),
      'text' => 'Yes, you can message me again.'
    )

    operator = create(:user, account: channel.account, role: :agent)
    channel.account.conversations.find_by!(display_id: stopped_lead.dig('conversation', 'display_id')).update!(assignee: operator)
    post "/api/v1/accounts/#{channel.account_id}/leads/#{stopped_lead.fetch('id')}/reconsent",
         params: candidate.slice('source_message_id', 'expected_event_id'),
         headers: operator.create_new_auth_token,
         as: :json
    expect(response).to have_http_status(:unauthorized)

    post "/api/v1/accounts/#{channel.account_id}/leads/#{stopped_lead.fetch('id')}/reconsent",
         params: candidate.slice('source_message_id', 'expected_event_id'),
         headers: admin.create_new_auth_token,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('detail', 'automated_contact_consent')).to include(
      'state' => 'granted',
      'reason' => 'administrator_recorded_explicit_reconsent',
      'evidence' => include('text' => 'Yes, you can message me again.', 'actor_type' => 'User')
    )

    post "/api/v1/accounts/#{channel.account_id}/leads/#{stopped_lead.fetch('id')}/reconsent",
         params: candidate.slice('source_message_id', 'expected_event_id'),
         headers: admin.create_new_auth_token,
         as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(LeadConsentEvent.where(account: channel.account, contact_id: stopped_lead.fetch('id')).count).to eq(2)
    expect(provider_request).not_to have_been_requested
  end

  it 'retains a delayed older withdrawal without replacing a newer grant' do
    sender = '255700000125'
    process_signed_message(body: 'Stop messaging me.', message_id: 'wamid.R05.ORDER.STOP', sender: sender)
    process_signed_message(
      body: 'Yes, you can message me again.', message_id: 'wamid.R05.ORDER.GRANT', sender: sender, timestamp: '1789000060'
    )
    stopped_lead = lead_for(sender, headers: admin.create_new_auth_token)
    candidate = stopped_lead.dig('detail', 'automated_contact_consent', 'reconsent_candidate')
    post "/api/v1/accounts/#{channel.account_id}/leads/#{stopped_lead.fetch('id')}/reconsent",
         params: candidate.slice('source_message_id', 'expected_event_id'), headers: admin.create_new_auth_token, as: :json

    process_signed_message(
      body: 'Stop messaging me.', message_id: 'wamid.R05.ORDER.DELAYED', sender: sender, timestamp: '1789000030'
    )

    consent = lead_for(sender, headers: admin.create_new_auth_token).dig('detail', 'automated_contact_consent')
    expect(consent).to include('state' => 'granted', 'evidence' => include('text' => 'Yes, you can message me again.'))
    expect(LeadConsentEvent.where(account: channel.account, contact_id: stopped_lead.fetch('id')).count).to eq(3)
  end

  it 'keeps withdrawal active across AI resume and replays the same provider event without duplicate effects' do
    sender = '255700000122'
    raw = signed_raw(body: 'Stop messaging me.', message_id: 'wamid.R05.REPLAY', sender: sender)
    process_raw_message(raw)
    lead = lead_for(sender, headers: admin.create_new_auth_token)
    conversation_id = lead.dig('conversation', 'display_id')
    evidence_id = lead.dig('detail', 'automated_contact_consent', 'evidence', 'id')

    post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation_id}/resume_ai",
         headers: admin.create_new_auth_token,
         as: :json
    expect(response).to have_http_status(:ok)

    process_raw_message(raw)
    replayed_lead = lead_for(sender, headers: admin.create_new_auth_token)
    expect(replayed_lead.dig('detail', 'automated_contact_consent')).to include(
      'state' => 'withdrawn',
      'evidence' => include('id' => evidence_id)
    )
    expect(LeadConsentEvent.where(account: channel.account, contact_id: replayed_lead.fetch('id')).count).to eq(1)
  end

  it 'shows the stop state while hiding evidence from an operator without access to its source conversation' do
    sender = '255700000123'
    process_signed_message(body: 'Tafadhali usinitumie ujumbe tena.', message_id: 'wamid.R05.ACCESS', sender: sender)
    admin_lead = lead_for(sender, headers: admin.create_new_auth_token)
    contact = channel.account.contacts.find(admin_lead.fetch('id'))
    operator = create(:user, account: channel.account, role: :agent)
    visible_conversation = create(
      :conversation,
      account: channel.account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact.contact_inboxes.find_by!(inbox: channel.inbox),
      assignee: operator,
      status: :resolved
    )

    operator_lead = lead_for(sender, headers: operator.create_new_auth_token)
    expect(operator_lead.dig('detail', 'automated_contact_consent')).to include('state' => 'withdrawn')
    expect(operator_lead.dig('detail', 'automated_contact_consent')).not_to have_key('evidence')

    get "/api/v1/accounts/#{channel.account_id}/conversations/#{visible_conversation.display_id}",
        headers: operator.create_new_auth_token,
        as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('automated_contact_consent')).to include('state' => 'withdrawn')
    expect(response.parsed_body.fetch('automated_contact_consent')).not_to have_key('evidence')
  end

  it 'loads consent state with a fixed query count for a real Conversation list' do
    create_conversation_for_phone('255700000131')
    single_count = consent_query_count
    4.times { |index| create_conversation_for_phone("25570000014#{index}") }

    page_count = consent_query_count

    expect(single_count).to be_positive
    expect(page_count).to eq(single_count)
  end

  it 'keeps inaccessible source evidence out of a preloaded Conversation list' do
    sender = '255700000132'
    process_signed_message(body: 'Stop messaging me.', message_id: 'wamid.R05.LIST.ACCESS', sender: sender)
    contact = channel.account.contacts.find(lead_for(sender, headers: admin.create_new_auth_token).fetch('id'))
    operator = create(:user, account: channel.account, role: :agent)
    visible_conversation = create_conversation_for_contact(contact, assignee: operator)

    get "/api/v1/accounts/#{channel.account_id}/conversations", headers: operator.create_new_auth_token, as: :json
    consent = response.parsed_body.dig('data', 'payload').find do |item|
      item.fetch('id') == visible_conversation.display_id
    end.fetch('automated_contact_consent')

    expect(consent).to include('state' => 'withdrawn')
    expect(consent).not_to have_key('evidence')
  end

  it 'invalidates pending automation across every Lead conversation and blocks a late follow-up delivery' do
    channel.inbox.update!(greeting_enabled: false)
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
    sender = '255700000124'
    process_signed_message(body: 'Hello', message_id: 'wamid.R05.PENDING.HELLO', sender: sender)
    lead = lead_for(sender, headers: admin.create_new_auth_token)
    contact = channel.account.contacts.find(lead.fetch('id'))
    first_conversation = channel.account.conversations.find_by!(display_id: lead.dig('conversation', 'display_id'))
    second_conversation = create(
      :conversation,
      account: channel.account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact.contact_inboxes.find_by!(inbox: channel.inbox)
    )
    conversations = [first_conversation, second_conversation]
    initial_versions = conversations.to_h { |item| [item.id, item.control_version] }
    intents = conversations.map do |item|
      existing = item.ai_orchestration_intents.where(state: %i[pending processing]).first
      next existing if existing

      trigger = item.messages.incoming.first || create(
        :message, account: channel.account, inbox: channel.inbox, conversation: item,
                  sender: contact, message_type: :incoming, content: 'Earlier message'
      )
      create(:ai_orchestration_intent, account: channel.account, conversation: item, triggering_message: trigger)
    end
    replies = conversations.map { |item| pending_reply_for(item) }
    follow_up = create(
      :lead_follow_up,
      account: channel.account,
      contact: contact,
      conversation: second_conversation,
      scheduled_at: 1.minute.ago
    )

    process_signed_message(
      body: 'Stop messaging me.',
      message_id: 'wamid.R05.PENDING.STOP',
      sender: sender,
      timestamp: '1789000060'
    )

    conversations.each do |item|
      expect(item.reload.control_version).to eq(initial_versions.fetch(item.id) + 1)
    end
    expect(intents.map { |intent| intent.reload.state }).to all(eq('blocked'))
    expect(replies.map { |reply| reply.reload.whatsapp_outbound_delivery.state }).to all(eq('canceled'))

    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform
    expect(follow_up.reload).to have_attributes(status: 'cancelled', cancellation_reason: 'follow_up_opted_out')
    expect(provider_request).not_to have_been_requested
  end

  private

  def post_signed_stop(body:, message_id:, sender: '255700000105', timestamp: '1789000000')
    raw = signed_raw(body: body, message_id: message_id, sender: sender, timestamp: timestamp)
    post_raw_message(raw)
  end

  def create_conversation_for_phone(phone)
    contact = create(:contact, account: channel.account, phone_number: "+#{phone}")
    create_conversation_for_contact(contact, source_id: phone)
  end

  def create_conversation_for_contact(contact, source_id: SecureRandom.hex(8), **attributes)
    contact_inbox = contact.contact_inboxes.find_by(inbox: channel.inbox) ||
                    create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: source_id)
    create(
      :conversation,
      account: channel.account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      **attributes
    )
  end

  def consent_query_count
    queries = []
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      next if payload[:cached]
      next unless payload[:sql].match?(/FROM "(?:lead_follow_up_opt_outs|lead_consent_events)"/)

      queries << payload[:sql]
    end
    get "/api/v1/accounts/#{channel.account_id}/conversations", headers: admin.create_new_auth_token, as: :json
    queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def process_signed_message(body:, message_id:, sender:, timestamp: '1789000000')
    post_signed_stop(body: body, message_id: message_id, sender: sender, timestamp: timestamp)
    Webhooks::WhatsappEventsJob.perform_now(response.parsed_body.fetch('receipt_id'))
  end

  def process_raw_message(raw)
    post_raw_message(raw)
    Webhooks::WhatsappEventsJob.perform_now(response.parsed_body.fetch('receipt_id'))
  end

  def post_raw_message(raw)
    signature = OpenSSL::HMAC.hexdigest('SHA256', signing_secret, raw)

    post "/webhooks/whatsapp/#{channel.phone_number}", params: raw,
                                                       headers: {
                                                         'CONTENT_TYPE' => 'application/json',
                                                         'X-Hub-Signature-256' => "sha256=#{signature}"
                                                       }
  end

  def signed_raw(body:, message_id:, sender:, timestamp: '1789000000')
    envelope(body: body, message_id: message_id, sender: sender, timestamp: timestamp).to_json
  end

  def lead_for(sender, headers:)
    get "/api/v1/accounts/#{channel.account_id}/leads",
        params: { q: sender, per_page: 100 },
        headers: headers,
        as: :json
    expect(response).to have_http_status(:ok)
    response.parsed_body.fetch('selected_lead')
  end

  def pending_reply_for(conversation)
    create(
      :message, :bot_message, account: channel.account, inbox: channel.inbox,
                              conversation: conversation, sender: nil, message_type: :outgoing,
                              content: 'Pending automated reply'
    )
  end

  def envelope(body:, message_id:, sender:, timestamp: '1789000000')
    {
      object: 'whatsapp_business_account',
      entry: [{
        id: channel.provider_config['business_account_id'],
        changes: [{
          field: 'messages',
          value: {
            metadata: {
              phone_number_id: channel.provider_config['phone_number_id'],
              display_phone_number: channel.phone_number.delete_prefix('+')
            },
            contacts: [{ wa_id: sender, profile: { name: "R05 Lead #{sender.last(3)}" } }],
            messages: [provider_message(body: body, message_id: message_id, sender: sender, timestamp: timestamp)]
          }
        }]
      }]
    }
  end

  def provider_message(body:, message_id:, sender:, timestamp:)
    { id: message_id, from: sender, timestamp: timestamp, type: 'text', text: { body: body } }
  end
end
