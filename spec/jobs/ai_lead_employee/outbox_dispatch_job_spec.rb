require 'rails_helper'

RSpec.describe AiLeadEmployee::OutboxDispatchJob do
  let(:channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:account) { channel.account }
  let(:operator) { create(:user, :administrator, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, assignee: operator) }
  let(:message) { create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: operator, message_type: :outgoing) }
  let(:event) do
    OutboxEvent.create!(account: account, aggregate: message, event_type: 'ai_employee.outbound_intent_recorded',
                        idempotency_key: "ai-outbound/test-#{message.id}", payload: { message_id: message.id })
  end
  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  before do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, message_type: :incoming, provider_created_at: Time.current)
  end

  def prepare_follow_up
    conversation.update!(assignee: nil, control_state: :ai_active)
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |key|
      create(:ai_lead_employee_evaluation_run, :reviewed_pass, account: account, user: operator, scenario_key: key)
    end
    evaluator = AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: 3)
    evaluator.approve!(user: operator, notes: 'Synthetic outgoing job test')
    follow_up = create(:lead_follow_up, account: account, conversation: conversation, contact: conversation.contact, scheduled_at: 1.minute.ago)
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform
    follow_up.reload
  end

  def accept_request
    stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.OUTBOX.ACCEPTED"}]}',
                                                headers: { 'Content-Type' => 'application/json' })
  end

  it 'records provider acceptance once across duplicate outbox jobs' do
    request = accept_request
    2.times { described_class.perform_now(event.id) }
    expect(request).to have_been_requested.once
    expect(event.reload).to have_attributes(state: 'delivered', attempts: 1)
    expect(message.reload.source_id).to eq('wamid.OUTBOX.ACCEPTED')
    expect(message.status).to eq('sent') # Provider delivered/read has not been established.
  end

  it 'marks a follow-up sent only after provider acceptance' do
    follow_up = prepare_follow_up
    request = accept_request
    described_class.perform_now
    expect(follow_up.reload).to be_sent
    expect(follow_up.sent_at).to be_present
    expect(request).to have_been_requested.once
  end

  it 'keeps the follow-up unsent and the outbox unknown after timeout without automatic retry' do
    follow_up = prepare_follow_up
    request = stub_request(:post, provider_url).to_timeout
    2.times { described_class.perform_now }
    expect(follow_up.reload).to be_pending
    expect(OutboxEvent.find_by!(aggregate: follow_up.message)).to be_unknown
    expect(request).to have_been_requested.once
  end

  it 'records a definite rejection as failed without requeuing the outbox' do
    request = stub_request(:post, provider_url).to_return(status: 400, body: '{"error":{"code":100}}',
                                                          headers: { 'Content-Type' => 'application/json' })
    2.times { described_class.perform_now(event.id) }
    expect(event.reload).to have_attributes(state: 'failed', failure_class: 'provider_rejected', delivered_at: nil)
    expect(message.reload).to be_failed
    expect(request).to have_been_requested.once
  end

  it 'does not dispatch a follow-up canceled after message creation' do
    follow_up = prepare_follow_up
    follow_up.cancel!('lead_responded')
    request = accept_request
    described_class.perform_now
    expect(OutboxEvent.find_by!(aggregate: follow_up.message)).to have_attributes(state: 'canceled', failure_class: 'follow_up_canceled')
    expect(request).not_to have_been_requested
  end

  it 'fails a cross-account payload and continues to the next valid event in the batch' do
    invalid = event
    other = create(:message)
    invalid.update!(payload: { message_id: other.id })
    valid_message = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: operator, message_type: :outgoing)
    valid = OutboxEvent.create!(account: account, aggregate: valid_message, event_type: 'ai_employee.outbound_intent_recorded',
                                idempotency_key: 'valid-next', payload: { message_id: valid_message.id })
    request = accept_request
    described_class.perform_now
    expect(invalid.reload).to have_attributes(state: 'failed', failure_class: 'InvalidDelivery')
    expect(valid.reload).to be_delivered
    expect(other.reload.source_id).to be_nil
    expect(request).to have_been_requested.once
  end
end
