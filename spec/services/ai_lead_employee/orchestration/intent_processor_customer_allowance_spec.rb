# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Orchestration::IntentProcessor do
  it 'captures the inbound message but blocks model work when the final reply credit is reserved' do
    account = create(:account)
    subscription = create(:ai_subscription, account: account, included_ai_replies: 1)
    consumed_intent = create(:ai_orchestration_intent, account: account)
    AiLeadEmployee::ReplyAllowance.reserve!(intent: consumed_intent).update!(status: :settled, settled_at: Time.current)
    conversation = create(:conversation, account: account, control_state: :ai_active, status: :open, assignee: nil)
    inbound = create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                               sender: conversation.contact, message_type: :incoming, content: 'What do you offer?')
    create(:knowledge_item, account: account, question: inbound.content, answer: 'We provide an approved service.')
    intent = create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: inbound)
    conversation.reload
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    expect(AiLeadEmployee::AiProvider::ClientFactory).not_to receive(:for)

    described_class.new(intent: intent, enqueue_deliveries: false).perform

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'customer_allowance_exhausted')
    expect(inbound.reload).to be_persisted
    expect(conversation.messages.outgoing).to be_empty
    expect(subscription.reload.action_required_alerted_at).to be_present
  end
end
