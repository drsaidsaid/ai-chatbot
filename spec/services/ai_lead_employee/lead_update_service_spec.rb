# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::LeadUpdateService do
  let(:account) { create(:account) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi') }
  let(:conversation) { create(:conversation, account: account, contact: contact, assignee: operator) }

  before do
    Current.user = operator
    conversation
  end

  after do
    Current.user = nil
  end

  it 'rejects fixed qualification evidence when no Offer criteria are configured' do
    expect(AiLeadEmployee::QualificationService).not_to receive(:new)

    expect do
      described_class.new(
        account: account,
        user: operator,
        contact: contact,
        attributes: { name: 'Jane Nkosi Updated', evidence: { problem: 'book demos automatically' } }
      ).perform
    end.to raise_error(ActiveRecord::RecordInvalid, /Configure an Offer/)

    expect(contact.reload.name).to eq('Jane Nkosi')
    expect(QualificationEvidence.where(account: account, contact: contact)).to be_empty
  end

  it 'validates required name and phone format through the Contact model' do
    expect do
      described_class.new(
        account: account,
        user: operator,
        contact: contact,
        attributes: { name: '', phone_number: 'not-a-phone' }
      ).perform
    end.to raise_error(ActiveRecord::RecordInvalid)

    expect(contact.reload.name).to eq('Jane Nkosi')
  end
end
