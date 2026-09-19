require 'rails_helper'

RSpec.describe AiLeadEmployee::BotHandoffDispatchJob do
  let(:conversation) { create(:conversation) }
  let(:event) do
    OutboxEvent.create!(
      account: conversation.account,
      aggregate: conversation,
      event_type: Conversations::ControlService::BOT_HANDOFF_EVENT_TYPE,
      idempotency_key: "bot-handoff-job/#{conversation.id}",
      payload: { conversation_id: conversation.id, control_version: 3 }
    )
  end

  it 'does not overwrite delivery with stale failure accounting' do
    stale_event = OutboxEvent.find(event.id)
    event.update!(state: :delivered, attempts: 1, delivered_at: Time.current)

    described_class.new.send(:record_failure, stale_event, RuntimeError.new('late failure'))

    expect(event.reload).to have_attributes(state: 'delivered', attempts: 1, failure_class: nil)
  end

  it 'keeps the event pending when the asynchronous dispatcher cannot enqueue' do
    allow(Rails.configuration.dispatcher).to receive(:dispatch).and_return(false)

    expect { described_class.perform_now(event.id) }
      .to raise_error(described_class::DispatchFailed, 'Bot handoff event enqueue failed')

    expect(event.reload).to have_attributes(state: 'pending', attempts: 1,
                                            failure_class: 'AiLeadEmployee::BotHandoffDispatchJob::DispatchFailed')
  end
end
