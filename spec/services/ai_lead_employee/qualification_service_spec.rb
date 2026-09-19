# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::QualificationService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'does not evaluate fixed questions or weights without a configured Offer' do
    expect(AiLeadEmployee::OfferQualificationService).not_to receive(:new)
    result = described_class.new(conversation: conversation).perform

    expect(result).to have_attributes(
      qualification: nil,
      qualification_mode: 'not_configured',
      next_question: nil,
      new_evidence: []
    )
    expect(LeadQualification.where(account: account, contact: conversation.contact)).to be_empty
    expect(QualificationEvidence.where(account: account, contact: conversation.contact)).to be_empty
  end
end
