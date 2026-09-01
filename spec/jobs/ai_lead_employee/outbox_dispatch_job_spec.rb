require 'rails_helper'

RSpec.describe AiLeadEmployee::OutboxDispatchJob do
  let(:account) { create(:account) }
  let(:message) { create(:message, account: account, message_type: :outgoing) }
  let(:event) do
    OutboxEvent.create!(
      account: account,
      aggregate: message,
      event_type: 'ai_employee.outbound_intent_recorded',
      idempotency_key: "ai-outbound/test-#{message.id}",
      payload: { message_id: message.id }
    )
  end

  it 'delivers a pending event exactly once across retries' do
    allow(SendReplyJob).to receive(:perform_now)

    described_class.perform_now(event.id)
    described_class.perform_now(event.id)

    expect(SendReplyJob).to have_received(:perform_now).with(message.id).once
    expect(event.reload).to have_attributes(state: 'delivered', attempts: 1)
    expect(event.delivered_at).to be_present
  end

  it 'marks a follow-up sent only after its message is delivered' do
    follow_up = create(:lead_follow_up, account: account, message: message)
    follow_up_event = OutboxEvent.create!(
      account: account,
      aggregate: message,
      event_type: 'ai_employee.follow_up_recorded',
      idempotency_key: "ai-follow-up/#{follow_up.id}",
      payload: { message_id: message.id, follow_up_id: follow_up.id }
    )
    allow(SendReplyJob).to receive(:perform_now)

    described_class.perform_now(follow_up_event.id)

    expect(follow_up.reload).to be_sent
    expect(follow_up.sent_at).to be_present
    expect(follow_up_event.reload).to be_delivered
  end

  it 'keeps the follow-up and event pending when delivery fails' do
    follow_up = create(:lead_follow_up, account: account, message: message)
    follow_up_event = OutboxEvent.create!(
      account: account,
      aggregate: message,
      event_type: 'ai_employee.follow_up_recorded',
      idempotency_key: "ai-follow-up/#{follow_up.id}",
      payload: { message_id: message.id, follow_up_id: follow_up.id }
    )
    allow(SendReplyJob).to receive(:perform_now).and_raise(StandardError, 'provider unavailable')

    expect do
      described_class.perform_now(follow_up_event.id)
    end.to have_enqueued_job(described_class).with(follow_up_event.id)

    expect(follow_up.reload).to be_pending
    expect(follow_up_event.reload).to be_pending
    expect(follow_up_event.failure_class).to eq('StandardError')
  end

  it 'keeps the event pending when SendReplyJob records a failed message without raising' do
    allow(SendReplyJob).to receive(:perform_now) do
      message.update!(status: :failed, content_attributes: { external_error: 'Authentication Error' })
    end

    expect do
      described_class.perform_now(event.id)
    end.to have_enqueued_job(described_class).with(event.id)

    expect(event.reload).to be_pending
    expect(event.failure_class).to eq('AiLeadEmployee::OutboxDispatchJob::DeliveryFailed')
    expect(event.delivered_at).to be_nil
  end

  it 'does not deliver a follow-up that was cancelled before dispatch' do
    follow_up = create(:lead_follow_up, account: account, message: message)
    follow_up_event = OutboxEvent.create!(
      account: account,
      aggregate: message,
      event_type: 'ai_employee.follow_up_recorded',
      idempotency_key: "ai-follow-up/#{follow_up.id}",
      payload: { message_id: message.id, follow_up_id: follow_up.id }
    )
    follow_up.cancel!('control_state_human_active')
    allow(SendReplyJob).to receive(:perform_now)

    described_class.perform_now(follow_up_event.id)

    expect(SendReplyJob).not_to have_received(:perform_now)
    expect(follow_up_event.reload).to have_attributes(state: 'failed', failure_class: 'FollowUpCancelled')
  end
end
