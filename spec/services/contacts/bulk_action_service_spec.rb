require 'rails_helper'

RSpec.describe Contacts::BulkActionService do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }

  it 'deletes the requested accessible contact for an Admin' do
    described_class.new(account: account, user: user, params: { ids: [contact.id], action_name: 'delete' }).perform
    expect(Contact.exists?(contact.id)).to be(false)
  end

  it 'adds labels to accessible contacts' do
    result = described_class.new(account: account, user: user, params: { ids: [contact.id], labels: { add: %w[vip support] } }).perform
    expect(result).to include(success: true, updated_contact_ids: [contact.id])
    expect(contact.reload.label_list).to contain_exactly('vip', 'support')
  end

  it 'removes only the requested labels from accessible contacts' do
    contact.update!(label_list: %w[vip support])
    result = described_class.new(account: account, user: user, params: { ids: [contact.id], labels: { remove: ['vip'] } }).perform
    expect(result).to include(success: true, updated_contact_ids: [contact.id])
    expect(contact.reload.label_list).to eq(['support'])
  end
end
