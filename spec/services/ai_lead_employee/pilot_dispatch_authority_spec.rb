# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::PilotDispatchAuthority do
  let(:account) { create(:account) }
  let(:provider) { create(:ai_provider_connection, account: account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700000001') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active)
  end
  let(:incoming) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Question')
  end
  let(:authorization) do
    AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: conversation.control_version, provider_configuration_version: provider.configuration_version,
      max_attempts: 1, max_spend_usd: 1, provider_limit_usd: 1,
      external_owner_approval_reference: 'test-owner-approval', provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
                                 verification_digest: 'sha256:response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
  end
  let(:intent) do
    create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: incoming,
                                     observed_control_version: conversation.control_version,
                                     pilot_authorization: authorization)
  end
  let(:usage) do
    AiLeadEmployee::AiProviderUsage.create!(
      account: account, ai_provider_connection: provider, pilot_authorization: authorization,
      ai_orchestration_intent: intent, configuration_version: provider.configuration_version,
      purpose: 'answer', period_on: Date.current, status: 'completed', requested_output_tokens: 50,
      cost_available: true, cost_usd: 0.10, started_at: 1.minute.ago, completed_at: Time.current
    )
  end
  let(:message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, message_type: :outgoing,
                     content: 'Answer', additional_attributes: {
                       ai_lead_employee: {
                         orchestration_intent_id: intent.id,
                         pilot_authorization_id: authorization.id,
                         provider_usage_id: usage.id
                       }
                     })
  end

  it 'allows the answer from the final admitted attempt after the attempt cap has been reached' do
    expect(described_class.new(message: message, conversation: conversation,
                               authorization: authorization, usage: usage).failure_code).to be_nil
  end

  it 'fails closed for pause, expiry, provider revision drift, takeover, and unknown cost', :aggregate_failures do
    authorization.update!(status: 'paused', paused_at: Time.current, pause_reason: 'operator_paused')
    expect(authority.failure_code).to eq('pilot_authorization_stopped')

    authorization.update!(status: 'active', expires_at: 1.second.ago)
    expect(authority.failure_code).to eq('pilot_authorization_expired')

    authorization.update!(expires_at: 1.hour.from_now)
    provider.update!(configuration_version: provider.configuration_version + 1)
    expect(authority.failure_code).to eq('pilot_provider_changed')

    provider.update!(configuration_version: authorization.provider_configuration_version)
    conversation.update!(control_state: :human_active, control_version: conversation.control_version + 1)
    expect(authority.failure_code).to eq('pilot_scope_changed')

    conversation.update!(control_state: :ai_active, control_version: authorization.control_version)
    usage.update!(cost_available: false, cost_usd: nil)
    expect(authority.failure_code).to eq('pilot_usage_invalid')
  end

  def authority
    described_class.new(message: message, conversation: conversation.reload,
                        authorization: authorization.reload, usage: usage.reload)
  end
end
