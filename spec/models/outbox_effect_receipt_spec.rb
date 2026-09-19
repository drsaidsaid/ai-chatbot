require 'rails_helper'

RSpec.describe OutboxEffectReceipt do
  let(:conversation) { create(:conversation) }
  let(:event) do
    OutboxEvent.create!(
      account: conversation.account,
      aggregate: conversation,
      event_type: Conversations::ControlService::BOT_HANDOFF_EVENT_TYPE,
      idempotency_key: "bot-handoff-receipt/#{conversation.id}",
      payload: { conversation_id: conversation.id }
    )
  end

  it 'commits one consumer effect across duplicate delivery' do
    effects = 0

    2.times do
      described_class.consume_once!(outbox_event_id: event.id, consumer: 'test') { effects += 1 }
    end

    expect(effects).to eq(1)
    expect(described_class.where(outbox_event: event, consumer: 'test').count).to eq(1)
  end

  it 'rolls back its receipt when the consumer effect fails' do
    expect do
      described_class.consume_once!(outbox_event_id: event.id, consumer: 'test') { raise 'effect failed' }
    end.to raise_error(RuntimeError, 'effect failed')

    expect(described_class.where(outbox_event: event, consumer: 'test')).to be_empty
    expect(described_class.consume_once!(outbox_event_id: event.id, consumer: 'test') { :retried }).to be(true)
  end
end
