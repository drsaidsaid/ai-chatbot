# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AiProvider::MeteredClient do
  self.use_transactional_tests = false

  before { clean_committed_fixtures }
  after { clean_committed_fixtures }

  let(:account) { create(:account) }
  let(:provider) { create(:ai_provider_connection, account: account, daily_request_limit: 100) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '255700000001') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active)
  end
  let(:message) do
    create(:message, account: account, inbox: inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Pilot question')
  end
  let(:intent) do
    create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: message,
                                     observed_control_version: conversation.control_version,
                                     pilot_authorization: authorization)
  end
  let(:authorization) do
    AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: inbox, contact: contact, conversation: conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app),
      recipient: contact_inbox.source_id, control_version: conversation.control_version,
      provider_configuration_version: provider.configuration_version,
      max_attempts: 1, max_spend_usd: 1, provider_limit_usd: 1, external_owner_approval_reference: 'test-owner-approval',
      provider_limit_verified_at: Time.current,
      provider_limit_evidence: {
        kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
        verification_digest: 'sha256:verified-response'
      },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
  end
  let(:adapter) { instance_double(AiLeadEmployee::AiProvider::OpenRouterAdapter) }
  let(:client) { described_class.new(connection: provider, adapter: adapter) }
  let(:response) do
    AiLeadEmployee::AiProvider::Response.new(
      id: 'provider-request-1', model: provider.model, content: 'Grounded answer', finish_reason: 'stop',
      input_tokens: 10, output_tokens: 4, total_tokens: 14, cost_usd: 0.02
    )
  end

  it 'records each admitted provider call against the Pilot Authorization and rejects a later call at the attempt cap' do
    allow(adapter).to receive(:complete).once.and_return(response)

    client.complete(messages: [{ role: 'user', content: 'Question' }], pilot_authorization: authorization,
                    orchestration_intent: intent)

    usage = AiLeadEmployee::AiProviderUsage.find_by!(pilot_authorization: authorization)
    expect(usage).to have_attributes(status: 'completed', ai_orchestration_intent_id: intent.id,
                                     cost_available: true, cost_usd: 0.02)
    expect do
      client.complete(messages: [{ role: 'user', content: 'Retry' }], pilot_authorization: authorization,
                      orchestration_intent: intent)
    end.to raise_error(AiLeadEmployee::AiProvider::PilotAdmissionFailure, /attempt limit/)
  end

  it 'denies a concurrent admission without pausing a valid in-flight authorization' do
    AiLeadEmployee::AiProviderUsage.create!(account: account, ai_provider_connection: provider,
                                            pilot_authorization: authorization, ai_orchestration_intent: intent,
                                            configuration_version: provider.configuration_version, purpose: 'answer',
                                            period_on: Date.current, status: 'reserved', requested_output_tokens: 10,
                                            started_at: 10.seconds.ago)

    expect do
      client.complete(messages: [{ role: 'user', content: 'Concurrent' }], pilot_authorization: authorization,
                      orchestration_intent: intent)
    end.to raise_error(AiLeadEmployee::AiProvider::PilotBusyFailure)
    expect(authorization.reload).to be_active
  end

  it 'counts a failed provider HTTP attempt against the pilot attempt cap' do
    allow(adapter).to receive(:complete).once.and_raise(AiLeadEmployee::AiProvider::TimeoutFailure)

    expect do
      client.complete(messages: [{ role: 'user', content: 'Question' }], pilot_authorization: authorization,
                      orchestration_intent: intent)
    end.to raise_error(AiLeadEmployee::AiProvider::TimeoutFailure)

    expect(AiLeadEmployee::AiProviderUsage.find_by!(pilot_authorization: authorization)).to be_failed
    expect(authorization.reload).to have_attributes(status: 'paused', pause_reason: 'provider_cost_unknown')
    expect do
      client.complete(messages: [{ role: 'user', content: 'Retry' }], pilot_authorization: authorization,
                      orchestration_intent: intent)
    end.to raise_error(AiLeadEmployee::AiProvider::PilotAdmissionFailure, /attempt limit/)
  end

  it 'rejects a persisted intent from another pilot scope before making a provider call' do
    other_conversation = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                                               control_state: :ai_active)
    other_message = create(:message, account: account, inbox: inbox, conversation: other_conversation, sender: contact,
                                     message_type: :incoming, content: 'Other question')
    other_intent = create(:ai_orchestration_intent, account: account, conversation: other_conversation,
                                                    triggering_message: other_message,
                                                    observed_control_version: other_conversation.control_version,
                                                    pilot_authorization: authorization)

    expect do
      client.complete(messages: [{ role: 'user', content: 'Question' }], pilot_authorization: authorization,
                      orchestration_intent: other_intent)
    end.to raise_error(AiLeadEmployee::AiProvider::PilotAdmissionFailure, /intent scope/)
    expect(adapter).not_to have_received(:complete)
  end

  it 'pauses the authorization and fails closed when provider cost is unavailable' do
    allow(adapter).to receive(:complete).and_return(response.tap { |value| value.cost_usd = nil })

    expect do
      client.complete(messages: [{ role: 'user', content: 'Question' }], pilot_authorization: authorization,
                      orchestration_intent: intent)
    end.to raise_error(AiLeadEmployee::AiProvider::AccountingUncertainFailure)

    expect(authorization.reload).to have_attributes(status: 'paused', pause_reason: 'provider_cost_unavailable')
    expect(AiLeadEmployee::AiProviderUsage.find_by!(pilot_authorization: authorization)).to have_attributes(
      status: 'completed', cost_available: false
    )
    expect(AiLeadEmployee::AiReplyUsage.where(ai_orchestration_intent: intent)).to be_empty
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
