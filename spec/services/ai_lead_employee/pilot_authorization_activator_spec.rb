# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::PilotAuthorizationActivator do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '255700000001') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active)
  end
  let(:connection) { create(:ai_provider_connection, account: account, api_key: 'sk-or-before') }
  let(:platform_app) { create(:platform_app, pilot_operations_enabled: true) }
  let(:verification) do
    AiLeadEmployee::AiProvider::OpenRouterKeyLimitVerifier::Result.new(
      limit_usd: 1, remaining_usd: 1, key_expires_at: nil, key_fingerprint: 'sha256:test',
      verification_digest: 'sha256:verified', verified_at: Time.current
    )
  end

  before do
    connection
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
  end

  it 'rejects activation when the verified provider configuration changes before locked construction' do
    verifier = instance_double(AiLeadEmployee::AiProvider::OpenRouterKeyLimitVerifier)
    allow(verifier).to receive(:perform) do
      AiLeadEmployee::AiProviderConnection.find(connection.id).update!(
        api_key: 'sk-or-after', configuration_version: connection.configuration_version + 1
      )
      verification
    end

    expect { activator(verifier).perform }.to raise_error(ActiveRecord::RecordInvalid)
    expect(AiLeadEmployee::PilotAuthorization.count).to eq(0)
  end

  it 'rejects activation when the verified operator loses current pilot permission before locked construction' do
    verifier = instance_double(AiLeadEmployee::AiProvider::OpenRouterKeyLimitVerifier)
    allow(verifier).to receive(:perform) do
      platform_app.update!(pilot_operations_enabled: false)
      verification
    end

    expect { activator(verifier).perform }.to raise_error(ActiveRecord::RecordInvalid)
    expect(AiLeadEmployee::PilotAuthorization.count).to eq(0)
  end

  def activator(verifier)
    described_class.new(account: account, conversation: conversation, max_attempts: 1, max_spend_usd: 1,
                        expires_at: 1.hour.from_now, platform_app: platform_app,
                        external_owner_approval_reference: 'owner-approval-r17-test', verifier: verifier)
  end
end
