# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::LeadUpdateService do
  let(:account) { create(:account) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:contact) { create(:contact, :with_phone_number, account: account, name: 'Jane Nkosi') }
  let(:conversation) { create(:conversation, account: account, contact: contact) }

  before do
    Current.user = operator
    create(:lead_qualification, account: account, contact: contact, quality: :unknown)
    conversation
  end

  after do
    Current.user = nil
  end

  it 'records audit history and recomputes qualification when human evidence changes' do
    described_class.new(
      account: account,
      user: operator,
      contact: contact,
      attributes: {
        name: 'Jane Nkosi Updated',
        business_name: 'Nuru Boutique',
        evidence: {
          problem: 'book demos automatically',
          budget: '$500 per month',
          urgency: 'this week',
          decision_authority: 'owner'
        }
      }
    ).perform

    contact.reload
    expect(contact.name).to eq('Jane Nkosi Updated')
    expect(contact.additional_attributes['company_name']).to eq('Nuru Boutique')
    expect(contact.lead_qualification.reload).to have_attributes(quality: 'highly_qualified', score: 80)
    expect(Audited::Audit.last).to have_attributes(auditable: contact, associated: account, user: operator)
    expect(Audited::Audit.last.audited_changes).to include(
      'ai_lead_employee_action' => 'lead_edit',
      'evidence_signals' => contain_exactly('problem', 'budget', 'urgency', 'decision_authority')
    )
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
