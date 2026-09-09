require 'rails_helper'

RSpec.describe 'Legacy macro queue authorization', type: :job do
  let(:account) { create(:account) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: nil) }
  let(:macro) do
    create(:macro, account: account, created_by: member, updated_by: member, visibility: :personal,
                   actions: [{ action_name: 'assign_agent', action_params: ['self'] },
                             { action_name: 'send_message', action_params: ['Unauthorized macro reply'] },
                             { action_name: 'send_webhook_event', action_params: ['https://example.test/blocked-macro'] }])
  end

  it 'discards an old personal macro that would self-assign, reply to and disclose an inaccessible Conversation' do
    MacrosExecutionJob.perform_later(macro, conversation_ids: [conversation.display_id], user: member)
    expect do
      perform_enqueued_jobs(only: MacrosExecutionJob)
    end.not_to change(Message, :count)
    expect(conversation.reload.assignee_id).to be_nil
    expect(enqueued_jobs.none? { |job| job[:job] == WebhookJob }).to be(true)
  end

  [:demotion, :revocation].each do |change|
    it "discards a legacy Admin macro after membership #{change} while queued" do
      membership = account.account_users.find_by!(user: member)
      membership.update!(role: :administrator)
      conversation.update!(assignee: member)
      MacrosExecutionJob.perform_later(macro, conversation_ids: [conversation.display_id], user: member)
      change == :demotion ? membership.update!(role: :agent) : membership.destroy!

      expect { perform_enqueued_jobs(only: MacrosExecutionJob) }.not_to change(Message, :count)
      expect(enqueued_jobs.none? { |job| job[:job] == WebhookJob }).to be(true)
    end
  end

  it 'runs an authorized legacy Admin macro only within its Business Account' do
    account.account_users.find_by!(user: member).update!(role: :administrator)
    other_conversation = create(:conversation, account: create(:account))
    macro.update!(actions: [{ action_name: 'add_label', action_params: ['legacy-admin'] }])
    MacrosExecutionJob.perform_later(macro, conversation_ids: [conversation.display_id, other_conversation.display_id], user: member)
    perform_enqueued_jobs(only: MacrosExecutionJob)

    expect(conversation.reload.label_list).to include('legacy-admin')
    expect(other_conversation.reload.label_list).to be_empty
  end
end
