# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Conversations::ControlService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account, control_state: :ai_active, control_version: 3) }
  let(:lead_message) { create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming) }
  let!(:pending_intent) do
    create(
      :ai_orchestration_intent,
      account: account,
      conversation: conversation,
      triggering_message: lead_message,
      observed_control_version: 3
    )
  end

  it 'invalidates pending AI work when a Human Operator takes over' do
    operator = create(:user, account: account)

    described_class.new(conversation: conversation).human_takeover!(operator: operator)

    expect(conversation.reload).to have_attributes(
      control_state: 'human_active',
      control_version: 4,
      assignee: operator
    )
    expect(pending_intent.reload).to have_attributes(
      state: 'blocked',
      blocked_reason: 'assigned_to_human_operator'
    )
  end

  it 'opens a handoff for Human Operators and blocks automation' do
    conversation.update!(status: :pending, assignee_agent_bot: create(:agent_bot, account: account))

    described_class.new(conversation: conversation).handoff_requested!

    expect(conversation.reload).to have_attributes(
      status: 'open',
      control_state: 'handoff_requested',
      control_version: 4,
      assignee_agent_bot: nil
    )
    expect(pending_intent.reload).to have_attributes(
      state: 'blocked',
      blocked_reason: 'incompatible_control_state'
    )
  end

  it 'invalidates incompatible follow-ups when AI is paused' do
    follow_up = create(:lead_follow_up, account: account, contact: conversation.contact, conversation: conversation)

    described_class.new(conversation: conversation).pause_ai!

    expect(conversation.reload).to be_ai_paused
    expect(pending_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'incompatible_control_state')
    expect(follow_up.reload).to have_attributes(status: 'cancelled', cancellation_reason: 'control_state_ai_paused')
  end

  it 'resumes only future eligible lead messages without reviving pending AI work' do
    conversation.update!(control_state: :ai_paused, control_version: 4)

    expect do
      described_class.new(conversation: conversation).resume_ai!
    end.not_to change(Message, :count)

    expect(conversation.reload).to have_attributes(control_state: 'ai_active', control_version: 5)
    expect(pending_intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'incompatible_control_state')
  end

  it 'does not resume a closed conversation' do
    conversation.update!(control_state: :closed, control_version: 4)

    expect do
      described_class.new(conversation: conversation).resume_ai!
    end.to raise_error(described_class::InvalidTransition)

    expect(conversation.reload).to have_attributes(control_state: 'closed', control_version: 4)
    expect(pending_intent.reload).to have_attributes(state: 'pending')
  end
end
