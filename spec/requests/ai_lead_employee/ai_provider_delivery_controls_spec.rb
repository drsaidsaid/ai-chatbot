# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI provider delivery controls', type: :request do
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:account) { channel.account }
  let(:admin) { create(:user, :administrator, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, control_state: :ai_active) }
  let(:endpoint) { "/api/v1/accounts/#{account.id}/ai_provider_connection" }

  before do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation,
                     message_type: :incoming, provider_created_at: Time.current)
    create(:ai_provider_connection, account: account, daily_request_limit: 10)
    approve_launch!
  end

  it 'cancels a pending automated delivery when an administrator disables the provider', :aggregate_failures do
    reply = create(:message, :bot_message, account: account, inbox: channel.inbox, conversation: conversation,
                                           sender: nil, message_type: :outgoing, content: 'Pending automated answer')
    delivery = reply.whatsapp_outbound_delivery
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})
                       .to_return(status: 200, body: { messages: [{ id: 'wamid.SHOULD.NOT.SEND' }] }.to_json)

    delete endpoint, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('status' => 'disabled', 'readiness_status' => 'disabled')
    expect(delivery.reload).to have_attributes(state: 'canceled', failure_code: 'provider_disabled')

    SendReplyJob.perform_now(reply.id)
    expect(provider_request).not_to have_been_requested
  end

  it 'cancels automated output created under an earlier provider configuration', :aggregate_failures do
    reply = create(:message, :bot_message, account: account, inbox: channel.inbox, conversation: conversation,
                                           sender: nil, message_type: :outgoing, content: 'Answer from the old model')
    delivery = reply.whatsapp_outbound_delivery

    patch endpoint,
          headers: admin.create_new_auth_token,
          params: { model: 'openai/gpt-5.2', reply_token_limit: 256, daily_request_limit: 10 },
          as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'configuration_version' => 2,
      'readiness_status' => 'not_checked'
    )
    expect(delivery.reload).to have_attributes(
      state: 'canceled',
      failure_code: 'provider_configuration_changed'
    )
  end

  it 'does not let provider-failure acknowledgment metadata bypass a disabled provider', :aggregate_failures do
    account.ai_provider_connection.disable!
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    reply = create(
      :message,
      :bot_message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: nil,
      message_type: :outgoing,
      content: 'Provider unavailable; a Human Operator will review this.',
      additional_attributes: { ai_lead_employee: { delivery_type: 'provider_failure_acknowledgment' } }
    )
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})

    SendReplyJob.perform_now(reply.id)

    expect(reply.whatsapp_outbound_delivery.reload).to have_attributes(state: 'canceled', failure_code: 'provider_disabled')
    expect(provider_request).not_to have_been_requested
  end

  private

  def approve_launch!
    connection = account.ai_provider_connection
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |scenario_key|
      create(
        :ai_lead_employee_evaluation_run,
        :reviewed_pass,
        account: account,
        user: admin,
        scenario_key: scenario_key,
        provider_snapshot: {
          'provider' => connection.provider,
          'model' => connection.model,
          'configuration_version' => connection.configuration_version
        }
      )
    end
    evaluator = AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: 3)
    evaluator.approve!(user: admin, notes: 'Synthetic R10 local test evidence only')
  end
end
