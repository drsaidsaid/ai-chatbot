require 'rails_helper'

RSpec.describe ActionCableBroadcastJob do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, :administrator, account: account) }
  let(:message) { create(:message, account: account, message_type: :outgoing) }

  %w[message.created message.updated].each do |event_name|
    context event_name do
      it 'broadcasts current Message data when an older event job runs while preserving its event changes' do
        changes = { 'status' => %w[sent delivered] }
        performer = { id: 17, name: 'Original operator' }
        stale = message.push_event_data.merge(previous_changes: changes, performer: performer, echo_id: 'original-client-echo')
        message.update!(status: :read)
        payloads = []
        allow(ActionCable.server).to receive(:broadcast) { |_stream, payload| payloads << payload }

        described_class.perform_now([admin.pubsub_token], event_name, stale)

        expect(payloads.sole.fetch(:data)).to include('status' => 'read', 'previous_changes' => changes, 'performer' => performer.stringify_keys)
        expect(payloads.sole.dig(:data, 'echo_id')).to eq(event_name == 'message.created' ? 'original-client-echo' : nil)
      end

      it 'does not retain removed attachments in an older queued update after native soft deletion' do
        attached = create(:message, :with_attachment, account: account, message_type: :outgoing)
        stale = attached.push_event_data
        expect(stale.fetch(:attachments)).to be_present
        attached.with_lock do
          attached.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
          attached.attachments.destroy_all
        end
        payloads = []
        allow(ActionCable.server).to receive(:broadcast) { |_stream, payload| payloads << payload }

        described_class.perform_now([admin.pubsub_token], event_name, stale)

        expect(payloads.sole.fetch(:data)).not_to have_key('attachments')
        expect(payloads.sole.dig(:data, 'content_attributes')).to eq('deleted' => true)
      end

      it 'does not broadcast a Message under another account from stale job arguments' do
        other_account = create(:account)
        data = message.push_event_data.merge(account_id: other_account.id)
        expect(ActionCable.server).not_to receive(:broadcast)

        described_class.perform_now([admin.pubsub_token], event_name, data)
      end

      it 'does not revive a deleted Message through an older queued update' do
        data = message.push_event_data
        message.destroy!
        expect(ActionCable.server).not_to receive(:broadcast)

        described_class.perform_now([admin.pubsub_token], event_name, data)
      end
    end
  end
end
