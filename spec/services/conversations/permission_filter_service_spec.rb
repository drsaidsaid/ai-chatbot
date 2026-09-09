require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:member) { create(:user, account: account, role: :agent) }
  let!(:assigned) { create(:conversation, account: account, assignee: member) }
  let!(:unassigned) { create(:conversation, account: account) }

  it 'keeps an Admin inside the selected Business Account even with a broad input relation' do
    create(:conversation)
    expect(described_class.new(Conversation.all, admin, account).perform).to contain_exactly(assigned, unassigned)
  end

  it 'requires current assignment despite shared inbox membership or the legacy planner option' do
    create(:inbox_member, user: member, inbox: unassigned.inbox)
    expect(described_class.new(Conversation.all, member, account, plan_hint_selective_filter: true).perform).to contain_exactly(assigned)
  end

  it 'rechecks role and membership when the same service is executed again' do
    service = described_class.new(Conversation.all, admin, account)
    membership = admin.account_users.find_by!(account: account)
    membership.update!(role: :agent)
    expect(service.perform).to be_empty
    assigned.update!(assignee: admin)
    expect(service.perform).to contain_exactly(assigned)
    membership.destroy!
    expect(service.perform).to be_empty
  end
end
