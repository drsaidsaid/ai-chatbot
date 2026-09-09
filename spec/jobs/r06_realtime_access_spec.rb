require 'rails_helper'

RSpec.describe 'Current assignment at realtime delivery', type: :job do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:colleague) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: member) }
  let(:message) { create(:message, account: account, conversation: conversation, content: 'Private Lead details') }

  before { allow(ActionCable.server).to receive(:broadcast) }

  around do |example|
    with_modified_env('SMTP_ADDRESS' => 'smtp.example.test') { example.run }
  end

  it 'drops previously queued Lead content after reassignment or membership revocation' do
    data = message.push_event_data.merge(account_id: account.id)
    tokens = [member.pubsub_token, admin.pubsub_token]
    conversation.update!(assignee: colleague)
    expect(ActionCable.server).to have_received(:broadcast).with(member.pubsub_token, { event: 'access.changed', data: { account_id: account.id } })
    ActionCableBroadcastJob.perform_now(tokens, 'message.created', data)
    expect(ActionCable.server).not_to have_received(:broadcast).with(member.pubsub_token, hash_including(event: 'message.created'))
    expect(ActionCable.server).to have_received(:broadcast).with(admin.pubsub_token, hash_including(event: 'message.created'))

    conversation.update!(assignee: member)
    member.account_users.find_by!(account: account).destroy!
    ActionCableBroadcastJob.perform_now(tokens, 'message.created', data)
    expect(ActionCable.server).not_to have_received(:broadcast).with(member.pubsub_token, hash_including(event: 'message.created'))
  end

  it 'delivers account contact events only to Admins and current assignees without an account-wide content stream' do
    data = conversation.contact.push_event_data.merge(account_id: account.id)
    colleague
    admin
    ActionCableBroadcastJob.perform_now(["account_#{account.id}"], 'contact.updated', data)
    expect(ActionCable.server).not_to have_received(:broadcast).with("account_#{account.id}", anything)
    expect(ActionCable.server).not_to have_received(:broadcast).with(colleague.pubsub_token, anything)
    expect(ActionCable.server).to have_received(:broadcast).with(member.pubsub_token, hash_including(event: 'contact.updated'))
  end

  it 'drops queued export work after an Admin becomes a Team Member' do
    admin.account_users.find_by!(account: account).update!(role: :agent)
    expect do
      Account::ContactsExportJob.perform_now(account.id, admin.id, [], {})
    end.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    expect(account.reload.contacts_export).not_to be_attached
  end

  it 'does not render queued conversation mail after reassignment' do
    message
    conversation.update!(assignee: colleague)
    mail = AgentNotifications::ConversationNotificationsMailer.with(account: account)
                                                              .conversation_mention(conversation, member, message)
    expect(mail.message).to be_a(ActionMailer::Base::NullMail)
  end

  it 'notifies an open session when its business membership is revoked' do
    member.account_users.find_by!(account: account).destroy!
    expect(ActionCable.server).to have_received(:broadcast).with(member.pubsub_token,
                                                                 { event: 'access.changed', data: { account_id: account.id } })
  end

  it 'does not give a dashboard member the contact socket credential through conversation events' do
    data = conversation.push_event_data.merge(account_id: account.id)
    ActionCableBroadcastJob.perform_now([member.pubsub_token], 'conversation.created', data)
    expect(ActionCable.server).to have_received(:broadcast) do |_token, payload|
      expect(payload.to_json).not_to include(conversation.contact_inbox.pubsub_token)
    end
  end
end
