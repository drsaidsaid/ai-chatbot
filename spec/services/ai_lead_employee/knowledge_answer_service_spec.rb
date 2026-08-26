# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::KnowledgeAnswerService do
  let(:account) { create(:account) }

  it 'answers from approved knowledge for the same Business Account' do
    item = create(:knowledge_item, account: account, question: 'Do you offer consulting?', answer: 'Yes, we offer consulting.')

    result = described_class.new(account: account, question: 'Do you offer consulting?').perform

    expect(result).to be_answered
    expect(result.answer).to eq('Yes, we offer consulting.')
    expect(result.sources).to contain_exactly(id: item.id, title: item.title, source_kind: 'faq')
  end

  it 'prefers FAQ, offer, and pricing knowledge over conflicting supporting documents' do
    create(:knowledge_item, account: account, source_kind: :supporting_document, question: 'What is your setup price?', answer: 'Setup is $10.')
    create(:knowledge_item, account: account, source_kind: :pricing, question: 'What is your setup price?', answer: 'Setup is $20.')

    result = described_class.new(account: account, question: 'What is your setup price?').perform

    expect(result.answer).to eq('Setup is $20.')
    expect(result.sources.first[:source_kind]).to eq('pricing')
  end

  it 'does not use unapproved rejected inactive or cross-tenant knowledge' do
    other_account = create(:account)
    create(:knowledge_item, account: account, status: :draft, question: 'Do you offer audits?', answer: 'Draft answer')
    create(:knowledge_item, account: account, status: :rejected, question: 'Do you offer audits?', answer: 'Rejected answer')
    create(
      :knowledge_item, account: account, status: :inactive, question: 'Do you offer audits?', answer: 'Inactive answer',
                       deactivated_at: Time.current
    )
    create(:knowledge_item, account: other_account, question: 'Do you offer audits?', answer: 'Other account answer')

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_refused
    expect(result.answer).to eq(described_class::BOUNDARY_RESPONSE)
    expect(result.sources).to be_empty
    expect(result.refusal_reason).to eq('no_approved_knowledge')
  end

  it 'refuses conflicting approved knowledge instead of choosing an answer' do
    create(:knowledge_item, account: account, source_kind: :faq, question: 'Do you offer audits?', answer: 'Yes.')
    create(:knowledge_item, account: account, source_kind: :faq, question: 'Do you offer audits?', answer: 'No.')

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_refused
    expect(result.answer).to eq(described_class::BOUNDARY_RESPONSE)
    expect(result.refusal_reason).to eq('conflicting_knowledge')
  end

  it 'refuses sensitive questions for Human Operator review' do
    result = described_class.new(account: account, question: 'Can you give legal advice about our contract?').perform

    expect(result).to be_refused
    expect(result.answer).to eq(described_class::BOUNDARY_RESPONSE)
    expect(result.refusal_reason).to eq('sensitive_question')
  end

  it 'refuses angry questions for Human Operator review' do
    result = described_class.new(account: account, question: 'I am furious about this terrible service').perform

    expect(result).to be_refused
    expect(result.answer).to eq(described_class::BOUNDARY_RESPONSE)
    expect(result.refusal_reason).to eq('angry_question')
  end
end
