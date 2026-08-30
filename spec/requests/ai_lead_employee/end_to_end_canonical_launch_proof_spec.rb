# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'End-to-end canonical launch proof', type: :request do
  let(:account) { create(:account) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:channel_secret) { 'ticket-006-whatsapp-secret' }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp,
           account: account,
           provider: 'whatsapp_cloud',
           sync_templates: false,
           validate_provider_config: false,
           provider_config: {
             'api_key' => 'test-whatsapp-token',
             'phone_number_id' => '123456789',
             'business_account_id' => '987654321',
             'app_secret' => channel_secret,
             'source' => 'embedded_signup'
           })
  end
  let(:sender_number) { '255700111240' }
  let(:provider_client) { instance_double(AiLeadEmployee::AiProvider::OpenRouterAdapter) }

  before do
    InstallationConfig.where(name: 'WHATSAPP_APP_SECRET').delete_all
    GlobalConfig.clear_cache
    whatsapp_channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome to AI Lead Employee.')
    create(:inbox_member, user: operator, inbox: whatsapp_channel.inbox)
    allow_retired_whatsapp_services
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
    Redis::Alfred.scan_each(match: 'MESSAGE_SOURCE_KEY::*') { |key| Redis::Alfred.delete(key) }
  end

  it 'proves the canonical WhatsApp launch path and records a deterministic launch report', :aggregate_failures do
    knowledge_item = create(:knowledge_item,
                            account: account,
                            title: 'AI employee offer FAQ',
                            question: 'Do you offer AI employees?',
                            answer: 'Yes, we build AI employees for qualified businesses.',
                            source_kind: :faq)
    allow(provider_client).to receive(:complete).and_return(provider_response)
    stub_whatsapp_delivery

    post_launch_inbound_twice
    records = launch_records

    expect(response).to have_http_status(:success)
    expect_retired_whatsapp_services_not_called
    expect_canonical_records(records, knowledge_item)
    expect_duplicate_inbound_to_have_one_logical_effect(records[:conversation])
    expect_existing_whatsapp_sender_delivery(records[:outbound_message])

    reconcile_delivery_statuses(records[:outbound_message])

    expect(records[:outbound_message].reload.status).to eq('read')
    expect(AiLeadEmployee::OrchestrationIntent.where(triggering_message: records[:outbound_message]).count).to eq(0)

    expect_retired_path_quarantined
    expect_launch_report(
      account: account,
      whatsapp_channel: whatsapp_channel,
      knowledge_items: [knowledge_item],
      orchestration_intent: records[:intent].reload,
      deterministic_checks: launch_checks,
      remaining_blockers: ['Live Meta test number verification is pending because no test credentials were provided.']
    )
  end

  it 'blocks stale AI jobs after takeover assignment pause resolution coexistence echo and explicit resume', :aggregate_failures do
    examples = {
      human_takeover: lambda { |conversation, intent|
        Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: operator)
        expect(intent.reload.blocked_reason).to eq('assigned_to_human_operator')
      },
      assignment: lambda { |conversation, intent|
        conversation.update!(assignee: operator)
        AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
        expect(intent.reload.blocked_reason).to eq('assigned_to_human_operator')
      },
      pause: lambda { |conversation, intent|
        Conversations::ControlService.new(conversation: conversation).pause_ai!
        expect(intent.reload.blocked_reason).to eq('incompatible_control_state')
      },
      resolution: lambda { |conversation, intent|
        conversation.update!(status: :resolved)
        AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
        expect(intent.reload.blocked_reason).to eq('ineligible_inbox_status')
      },
      coexistence_echo: lambda { |conversation, intent|
        Whatsapp::IncomingMessageWhatsappCloudService.new(
          inbox: whatsapp_channel.inbox,
          params: echo_payload(conversation.contact_inbox.source_id),
          outgoing_echo: true
        ).perform
        expect(intent.reload.blocked_reason).to eq('human_reply_after_trigger')
      }
    }

    examples.each_value do |action|
      conversation, intent = stale_job_fixture
      action.call(conversation, intent)
      expect(intent.reload).to be_blocked
      expect(conversation.messages.outgoing.where(private: false).where.not(content: 'Handled in WhatsApp.')).to be_empty
    end

    conversation, intent = stale_job_fixture
    Conversations::ControlService.new(conversation: conversation).pause_ai!
    expect do
      Conversations::ControlService.new(conversation: conversation.reload).resume_ai!
    end.not_to change(Message, :count)
    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'incompatible_control_state')

    resumed_lead_message = create(:message,
                                  account: account,
                                  inbox: whatsapp_channel.inbox,
                                  conversation: conversation,
                                  sender: conversation.contact,
                                  message_type: :incoming,
                                  content: 'Do you offer AI employees?',
                                  source_id: 'wamid.RESUMED.LAUNCH')
    expect(AiLeadEmployee::OrchestrationIntentRecorder.new(message: resumed_lead_message).perform).to be_pending
  end

  it 'classifies provider failures and source-unverified answers without fabricated fallback content', :aggregate_failures do
    provider_failures = {
      authentication_failure: AiLeadEmployee::AiProvider::AuthenticationFailure,
      timeout: AiLeadEmployee::AiProvider::TimeoutFailure,
      rate_limit: AiLeadEmployee::AiProvider::RateLimitFailure,
      invalid_response: AiLeadEmployee::AiProvider::InvalidResponseFailure
    }

    provider_failures.each do |failure_class, error_class|
      _conversation, intent = provider_failure_fixture("wamid.PROVIDER.#{failure_class.to_s.upcase}")
      allow(provider_client).to receive(:complete).and_raise(error_class.new)

      AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)

      expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_failure', failure_class: failure_class.to_s)
      expect(intent.review_request).to have_attributes(reason: 'provider_failed', status: 'open')
      expect(intent.conversation.messages.outgoing.where(private: false)).to be_empty
    end

    conversation, intent = provider_failure_fixture('wamid.PROVIDER.SOURCE.UNVERIFIED')
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(id: 'provider-review', model: 'openai/gpt-5.2', content: 'REVIEW_REQUIRED', finish_reason: 'stop')
    )

    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
    expect(intent.review_request).to have_attributes(reason: 'source_unverified', status: 'open')
    expect(conversation.messages.outgoing.where(private: false)).to be_empty
  end

  it 'denies cross-tenant access to launch proof records and configuration', :aggregate_failures do
    records = other_tenant_records

    expect_account_membership_denial(records)
    expect_same_account_foreign_records_hidden(records)
    expect_provider_configuration_isolated(records)
    expect_orchestration_records_scoped(records)
  end

  def other_tenant_records
    other_account = create(:account)
    other_channel = other_whatsapp_channel(other_account)
    other_contact = create(:contact, account: other_account, contact_type: :lead)
    other_conversation = other_conversation_for(other_account, other_channel, other_contact)
    other_message = other_message_for(other_account, other_channel, other_contact, other_conversation)
    other_review_request = create(:human_review_request, account: other_account, conversation: other_conversation,
                                                         lead_message: other_message)
    {
      account: other_account,
      contact: other_contact,
      conversation: other_conversation,
      knowledge: create(:knowledge_item, account: other_account),
      review_request: other_review_request,
      provider_connection: create(:ai_provider_connection, account: other_account, api_key: nil, status: :disabled, model: 'openai/gpt-5.2'),
      intent: create(:ai_orchestration_intent, account: other_account, conversation: other_conversation, triggering_message: other_message),
      message: other_message
    }
  end

  def other_whatsapp_channel(other_account)
    create(:channel_whatsapp,
           account: other_account,
           provider: 'whatsapp_cloud',
           sync_templates: false,
           validate_provider_config: false)
  end

  def other_conversation_for(other_account, other_channel, other_contact)
    other_contact_inbox = create(:contact_inbox, contact: other_contact, inbox: other_channel.inbox, source_id: '255700111299')
    create(:conversation,
           account: other_account,
           inbox: other_channel.inbox,
           contact: other_contact,
           contact_inbox: other_contact_inbox)
  end

  def other_message_for(other_account, other_channel, other_contact, other_conversation)
    create(:message,
           account: other_account,
           inbox: other_channel.inbox,
           conversation: other_conversation,
           sender: other_contact,
           message_type: :incoming)
  end

  def expect_account_membership_denial(records)
    foreign_account_paths(records).each do |path|
      expect_json_get(path, headers: operator.create_new_auth_token, status: :unauthorized)
    end
  end

  def expect_same_account_foreign_records_hidden(records)
    current_account_foreign_record_paths(records).each do |path|
      expect_json_get(path, headers: admin.create_new_auth_token, status: :not_found)
    end
  end

  def expect_provider_configuration_isolated(records)
    expect_provider_configuration_unauthorized(records)
    expect_provider_configuration_not_leaked(records[:provider_connection])
  end

  def expect_provider_configuration_unauthorized(records)
    [
      "/api/v1/accounts/#{records[:account].id}/ai_provider_connection",
      "/api/v1/accounts/#{account.id}/ai_provider_connection"
    ].each do |path|
      expect_json_get(path, headers: operator.create_new_auth_token, status: :unauthorized)
    end
  end

  def expect_provider_configuration_not_leaked(provider_connection)
    expect_json_get("/api/v1/accounts/#{account.id}/ai_provider_connection", headers: admin.create_new_auth_token, status: :success)
    expect(response.parsed_body).to include('status' => 'disabled', 'has_credentials' => false)
    expect(response.parsed_body.to_json).not_to include(provider_connection.id.to_s, provider_connection.model)
  end

  def foreign_account_paths(records)
    [
      "/api/v1/accounts/#{records[:account].id}/contacts/#{records[:contact].id}",
      "/api/v1/accounts/#{records[:account].id}/conversations/#{records[:conversation].display_id}",
      "/api/v1/accounts/#{records[:account].id}/knowledge_items/#{records[:knowledge].id}",
      "/api/v1/accounts/#{records[:account].id}/human_review_requests/#{records[:review_request].id}"
    ]
  end

  def current_account_foreign_record_paths(records)
    [
      "/api/v1/accounts/#{account.id}/contacts/#{records[:contact].id}",
      "/api/v1/accounts/#{account.id}/conversations/#{records[:conversation].display_id}",
      "/api/v1/accounts/#{account.id}/knowledge_items/#{records[:knowledge].id}",
      "/api/v1/accounts/#{account.id}/human_review_requests/#{records[:review_request].id}"
    ]
  end

  def expect_json_get(path, headers:, status:)
    get path, headers: headers, as: :json
    expect(response).to have_http_status(status)
  end

  def expect_orchestration_records_scoped(records)
    expect(AiLeadEmployee::OrchestrationIntent.where(account: account).find_by(id: records[:intent].id)).to be_nil
    expect do
      create(:ai_orchestration_intent, account: account, conversation: records[:conversation], triggering_message: records[:message])
    end.to raise_error(ActiveRecord::RecordInvalid, /must belong to the same account/)
  end

  def post_launch_inbound_twice
    perform_enqueued_jobs do
      post_whatsapp_payload(inbound_payload(message_id: 'wamid.LAUNCH.INBOUND', body: 'Do you offer AI employees?'))
      post_whatsapp_payload(inbound_payload(message_id: 'wamid.LAUNCH.INBOUND', body: 'Do you offer AI employees?'))
    end
  end

  def launch_records
    conversation = whatsapp_channel.inbox.conversations.first
    inbound_message = conversation.messages.incoming.find_by!(source_id: 'wamid.LAUNCH.INBOUND')
    intent = AiLeadEmployee::OrchestrationIntent.find_by!(triggering_message: inbound_message)

    {
      conversation: conversation,
      lead: account.contacts.find_by!(phone_number: "+#{sender_number}"),
      inbound_message: inbound_message,
      greeting: conversation.messages.template.find_by!(content: 'Welcome to AI Lead Employee.'),
      intent: intent,
      outbound_message: intent.outbound_message
    }
  end

  # rubocop:disable Metrics/AbcSize
  def expect_canonical_records(records, knowledge_item)
    lead = records.fetch(:lead)
    conversation = records.fetch(:conversation)
    inbound_message = records.fetch(:inbound_message)
    greeting = records.fetch(:greeting)
    intent = records.fetch(:intent)
    outbound_message = records.fetch(:outbound_message)

    expect_lead_and_conversation(lead, conversation, inbound_message, greeting)
    expect_grounded_intent(intent, conversation, knowledge_item)
    expect_ai_outbound_message(outbound_message, conversation, intent, knowledge_item)
  end

  def expect_lead_and_conversation(lead, conversation, inbound_message, greeting)
    expect(lead).to have_attributes(account_id: account.id, name: 'Launch Proof Lead', phone_number: "+#{sender_number}", contact_type: 'lead')
    expect(conversation).to have_attributes(account_id: account.id, inbox_id: whatsapp_channel.inbox.id, contact_id: lead.id)
    expect(inbound_message).to have_attributes(account_id: account.id, message_type: 'incoming', content: 'Do you offer AI employees?')
    expect(greeting).to have_attributes(account_id: account.id, message_type: 'template', content: 'Welcome to AI Lead Employee.')
    expect(conversation.messages.chat.order(:created_at, :id).map(&:content)).to eq(
      ['Do you offer AI employees?', 'Welcome to AI Lead Employee.', 'Yes, we build AI employees for qualified businesses.']
    )
  end

  def expect_grounded_intent(intent, conversation, knowledge_item)
    expect(intent).to have_attributes(account_id: account.id, conversation_id: conversation.id, state: 'completed',
                                      selected_provider: nil, model: 'openai/gpt-5.2')
    expect(intent.source_references).to contain_exactly(
      include('id' => knowledge_item.id, 'title' => 'AI employee offer FAQ', 'status' => 'verified',
              'source_reference' => knowledge_item.source_reference)
    )
  end

  def expect_ai_outbound_message(outbound_message, conversation, intent, knowledge_item)
    expect(outbound_message).to have_attributes(account_id: account.id, inbox_id: whatsapp_channel.inbox.id,
                                                conversation_id: conversation.id, message_type: 'outgoing',
                                                content: 'Yes, we build AI employees for qualified businesses.',
                                                private: false)
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'orchestration_intent_id')).to eq(intent.id)
    expect(outbound_message.additional_attributes.dig('ai_lead_employee', 'source_references').first['id']).to eq(knowledge_item.id)
    expect(OutboxEvent.find_by!(aggregate: outbound_message)).to have_attributes(account_id: account.id,
                                                                                 event_type: 'ai_employee.outbound_intent_recorded')
  end

  def expect_duplicate_inbound_to_have_one_logical_effect(conversation)
    expect_tenant_identity_counts
    expect_message_side_effect_counts(conversation)
  end

  def expect_tenant_identity_counts
    expect(account.contacts.where(phone_number: "+#{sender_number}").count).to eq(1)
    expect(whatsapp_channel.inbox.contact_inboxes.where(source_id: sender_number).count).to eq(1)
    expect(whatsapp_channel.inbox.conversations.count).to eq(1)
  end

  def expect_message_side_effect_counts(conversation)
    expect(conversation.messages.incoming.where(source_id: 'wamid.LAUNCH.INBOUND').count).to eq(1)
    expect(conversation.messages.template.where(content: 'Welcome to AI Lead Employee.').count).to eq(1)
    expect(AiLeadEmployee::OrchestrationIntent.where(conversation: conversation).count).to eq(1)
    expect(conversation.messages.outgoing.where(private: false).count).to eq(1)
    expect(OutboxEvent.where(event_type: 'ai_employee.outbound_intent_recorded').count).to eq(1)
  end

  def expect_existing_whatsapp_sender_delivery(outbound_message)
    expect(outbound_message.source_id).to eq('wamid.LAUNCH.AI.SENT')
    expect(a_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
      .with { |request| JSON.parse(request.body).dig('text', 'body') == 'Welcome to AI Lead Employee.' }).to have_been_made.once
    expect(a_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
      .with { |request| JSON.parse(request.body).dig('text', 'body') == provider_response.content }).to have_been_made.once
  end

  def reconcile_delivery_statuses(outbound_message)
    perform_enqueued_jobs do
      post_whatsapp_payload(status_payload(message_id: outbound_message.source_id, status: 'delivered'))
      post_whatsapp_payload(status_payload(message_id: outbound_message.source_id, status: 'read'))
    end
  end

  def expect_retired_path_quarantined
    expect do
      post '/webhooks/meta/whatsapp',
           params: inbound_payload(message_id: 'wamid.RETIRED.PATH', body: 'Wrong route').to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }
    end.not_to change(Message, :count)
    expect(response).to have_http_status(:gone)
    expect_retired_whatsapp_services_not_called
  end

  def expect_launch_report(attributes)
    launch_report = AiLeadEmployee::LaunchProofReport.new(attributes)
    report = launch_report.to_h

    expect_launch_report_summary(report)
    expect_launch_report_versions(report, attributes)
    expect_launch_report_markdown(launch_report, attributes)
  end

  def expect_launch_report_summary(report)
    expect(report).to include(
      proof: 'end_to_end_canonical_launch_proof',
      canonical_webhook_path: '/webhooks/whatsapp/:phone_number',
      retired_webhook_path: '/webhooks/meta/whatsapp',
      provider_model: 'openai/gpt-5.2',
      test_number_status: 'absent'
    )
    expect(report[:tested_code_version]).to match(/\A[0-9a-f]{40}\z/)
    expect(report[:deterministic_checks]).to match_array(launch_checks)
    expect(report[:human_verification_path].join("\n")).to include('/webhooks/whatsapp/:phone_number')
  end

  def expect_launch_report_versions(report, attributes)
    expect(report[:configuration_versions]).to include(
      whatsapp_channel: include(id: whatsapp_channel.id, updated_at: whatsapp_channel.reload.updated_at.iso8601)
    )
    expect(report[:knowledge_versions]).to contain_exactly(
      include(id: attributes[:knowledge_items].first.id,
              source_reference: attributes[:knowledge_items].first.source_reference,
              approved_at: attributes[:knowledge_items].first.approved_at.iso8601)
    )
  end

  def expect_launch_report_markdown(launch_report, attributes)
    markdown = launch_report.to_markdown
    expect(markdown).to include('## Configuration Versions', '## Knowledge Versions', '## Source References')
    expect(markdown).to include(whatsapp_channel.provider_config['phone_number_id'], attributes[:knowledge_items].first.source_reference)
  end
  # rubocop:enable Metrics/AbcSize

  def provider_response
    AiLeadEmployee::AiProvider::Response.new(
      id: 'provider-launch-proof',
      model: 'openai/gpt-5.2',
      content: 'Yes, we build AI employees for qualified businesses.',
      finish_reason: 'stop'
    )
  end

  def post_whatsapp_payload(payload)
    body = payload.to_json
    post "/webhooks/whatsapp/#{whatsapp_channel.phone_number}",
         params: body,
         headers: { 'CONTENT_TYPE' => 'application/json', 'X-Hub-Signature-256' => signature_for(body) }
  end

  def signature_for(body)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', channel_secret, body)}"
  end

  def inbound_payload(message_id:, body:)
    canonical_webhook_payload(
      contacts: [{ profile: { name: 'Launch Proof Lead' }, wa_id: sender_number }],
      messages: [{ from: sender_number, id: message_id, timestamp: '1787740800', text: { body: body }, type: 'text' }]
    )
  end

  def status_payload(message_id:, status:)
    canonical_webhook_payload(
      statuses: [{ id: message_id, status: status, timestamp: '1787740801', recipient_id: sender_number }]
    )
  end

  def canonical_webhook_payload(value)
    {
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          field: 'messages',
          value: {
            messaging_product: 'whatsapp',
            metadata: {
              display_phone_number: whatsapp_channel.phone_number.delete_prefix('+'),
              phone_number_id: whatsapp_channel.provider_config['phone_number_id']
            }
          }.merge(value)
        }]
      }]
    }
  end

  def stub_whatsapp_delivery
    stub_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
      .to_return do |request|
        content = JSON.parse(request.body).dig('text', 'body')
        meta_id = content == 'Welcome to AI Lead Employee.' ? 'wamid.LAUNCH.GREETING.SENT' : 'wamid.LAUNCH.AI.SENT'
        {
          status: 200,
          body: { messages: [{ id: meta_id }] }.to_json,
          headers: { 'content-type' => 'application/json' }
        }
      end
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

  def stale_job_fixture
    contact = stale_contact
    conversation = stale_conversation(contact)
    lead_message = stale_lead_message(conversation, contact)
    intent = create(:ai_orchestration_intent,
                    account: account,
                    conversation: conversation,
                    triggering_message: lead_message,
                    observed_control_version: 4)
    [conversation, intent]
  end

  def stale_contact
    create(
      :contact,
      account: account,
      phone_number: "+#{SecureRandom.random_number(900_000_000) + 100_000_000}"
    )
  end

  def stale_conversation(contact)
    contact_inbox = create(
      :contact_inbox,
      contact: contact,
      inbox: whatsapp_channel.inbox,
      source_id: contact.phone_number.delete_prefix('+')
    )
    create(:conversation,
           account: account,
           inbox: whatsapp_channel.inbox,
           contact: contact,
           contact_inbox: contact_inbox,
           control_state: :ai_active,
           control_version: 4,
           assignee: nil,
           status: :open)
  end

  def stale_lead_message(conversation, contact)
    create(:message,
           account: account,
           inbox: whatsapp_channel.inbox,
           conversation: conversation,
           sender: contact,
           message_type: :incoming,
           content: 'Do you offer AI employees?',
           source_id: "wamid.STALE.#{SecureRandom.hex(4)}")
  end

  def echo_payload(source_id)
    {
      phone_number: whatsapp_channel.phone_number,
      object: 'whatsapp_business_account',
      entry: [{
        changes: [{
          field: 'smb_message_echoes',
          value: {
            metadata: {
              phone_number_id: whatsapp_channel.provider_config['phone_number_id'],
              display_phone_number: whatsapp_channel.phone_number.delete_prefix('+')
            },
            message_echoes: [echo_message(source_id)]
          }
        }]
      }]
    }.with_indifferent_access
  end

  def echo_message(source_id)
    {
      from: whatsapp_channel.phone_number.delete_prefix('+'),
      to: source_id,
      id: "wamid.ECHO.#{SecureRandom.hex(4)}",
      text: { body: 'Handled in WhatsApp.' },
      timestamp: '1787740800',
      type: 'text'
    }
  end

  def provider_failure_fixture(source_id)
    conversation, intent = stale_job_fixture
    intent.triggering_message.update!(source_id: source_id)
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    [conversation, intent]
  end

  def launch_checks
    [
      'canonical webhook accepted verified payload',
      'retired meta webhook returned gone',
      'duplicate inbound created one logical effect',
      'lead conversation and inbound message were tenant scoped',
      'channel greeting was visible and sent once',
      'durable orchestration completed with verified source references',
      'outbound message used existing whatsapp sender and stored meta id',
      'delivery statuses reconciled onto outbound message',
      'no retired custom meta service was called'
    ]
  end
end
