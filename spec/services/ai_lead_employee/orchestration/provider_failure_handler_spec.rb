# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Orchestration::ProviderFailureHandler do
  let(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:conversation) { create(:conversation, account: account, inbox: whatsapp_channel.inbox) }
  let(:lead_message) do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming, content: 'Can you help?')
  end
  let(:intent) { create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: lead_message) }

  it 'records a safe orchestration outcome when a configured provider fails', :aggregate_failures do
    failure = AiLeadEmployee::AiProvider::TimeoutFailure.new

    described_class.new(intent: intent, failure: failure).perform

    expect(intent.reload).to be_blocked
    expect(intent.failure_class).to eq('timeout')
    expect(intent.blocked_reason).to eq('provider_failure')
    expect(intent.outbound_message).to be_nil
    expect(conversation.messages.outgoing.where(private: false)).to be_empty
  end
end
