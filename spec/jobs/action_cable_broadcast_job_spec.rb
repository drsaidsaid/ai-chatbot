require 'rails_helper'

RSpec.describe ActionCableBroadcastJob do
  let(:message) { create(:message, message_type: :outgoing) }

  it 'broadcasts current Message data when an older update job runs while preserving its event changes' do
    changes = { 'status' => %w[sent delivered] }
    performer = { id: 17, name: 'Original operator' }
    stale = message.push_event_data.merge(previous_changes: changes, performer: performer)
    message.update!(status: :read)
    payloads = []
    allow(ActionCable.server).to receive(:broadcast) { |_stream, payload| payloads << payload }

    described_class.perform_now(['synthetic-stream'], 'message.updated', stale)

    expect(payloads.sole.fetch(:data)).to include(status: 'read', previous_changes: changes, performer: performer)
  end

  it 'does not retain removed attachments in an older queued update after native soft deletion' do
    attached = create(:message, :with_attachment, message_type: :outgoing)
    stale = attached.push_event_data
    expect(stale.fetch(:attachments)).to be_present
    attached.with_lock do
      attached.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      attached.attachments.destroy_all
    end
    payloads = []
    allow(ActionCable.server).to receive(:broadcast) { |_stream, payload| payloads << payload }

    described_class.perform_now(['synthetic-stream'], 'message.updated', stale)

    expect(payloads.sole.fetch(:data)).not_to have_key(:attachments)
    expect(payloads.sole.dig(:data, :content_attributes)).to eq('deleted' => true)
  end

  it 'does not broadcast a Message under another account from stale job arguments' do
    other_account = create(:account)
    data = message.push_event_data.merge(account_id: other_account.id)
    expect(ActionCable.server).not_to receive(:broadcast)

    described_class.perform_now(['synthetic-stream'], 'message.updated', data)
  end

  it 'does not revive a deleted Message through an older queued update' do
    data = message.push_event_data
    message.destroy!
    expect(ActionCable.server).not_to receive(:broadcast)

    described_class.perform_now(['synthetic-stream'], 'message.updated', data)
  end
end
