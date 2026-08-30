# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::KnowledgeAnswerService do
  let(:account) { create(:account) }

  it 'answers from approved knowledge for the same Business Account' do
    item = create(:knowledge_item, account: account, question: 'Do you offer consulting?', answer: 'Yes, we offer consulting.')

    result = described_class.new(account: account, question: 'Do you offer consulting?').perform

    expect(result).to be_answered
    expect(result.answer).to eq('Yes, we offer consulting.')
    expect(result.sources).to contain_exactly(
      include(id: item.id, title: item.title, source_kind: 'faq', status: 'verified')
    )
  end

  it 'prefers FAQ, offer, pricing, objection, and policy knowledge over supporting documents' do
    create(:knowledge_item, account: account, source_kind: :supporting_document, question: 'What is your setup price?', answer: 'Setup is $10.')
    create(:knowledge_item, account: account, source_kind: :policy, question: 'What is your setup price?', answer: 'Setup is $15.')
    create(:knowledge_item, account: account, source_kind: :objection, question: 'What is your setup price?', answer: 'Setup is $18.')
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
    expect(result.answer).to be_nil
    expect(result.sources).to be_empty
    expect(result.refusal_reason).to eq('no_approved_knowledge')
  end

  it 'does not use approved knowledge without a verified Source Reference' do
    create(
      :knowledge_item,
      account: account,
      question: 'Do you offer audits?',
      answer: 'Yes, audits are available.',
      metadata: { source_reference: '' }
    )

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_refused
    expect(result.answer).to be_nil
    expect(result.sources).to be_empty
    expect(result.refusal_reason).to eq('source_unverified')
  end

  it 'does not use knowledge changed after approval' do
    item = create(:knowledge_item, account: account, question: 'Do you offer audits?', answer: 'Yes, audits are available.')
    item.update!(answer: 'Changed after approval', approved_at: 5.minutes.ago)

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_refused
    expect(result.answer).to be_nil
    expect(result.refusal_reason).to eq('source_unverified')
  end

  it 'uses changed knowledge only after a fresh admin approval' do
    item = create(:knowledge_item, account: account, question: 'Do you offer audits?', answer: 'Yes, audits are available.', metadata: {})
    original_source_reference = item.source_reference
    item.update!(answer: 'Changed after approval', approved_at: 5.minutes.ago)
    item.approve!

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_answered
    expect(result.answer).to eq('Changed after approval')
    expect(result.sources.first[:source_reference]).not_to eq(original_source_reference)
  end

  it 'does not use stale approved knowledge' do
    create(
      :knowledge_item,
      account: account,
      question: 'Do you offer audits?',
      answer: 'Yes, audits are available.',
      metadata: {
        source_reference: 'policy-handbook-audits',
        expires_at: 1.day.ago.iso8601
      }
    )

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_refused
    expect(result.answer).to be_nil
    expect(result.refusal_reason).to eq('stale_knowledge')
  end

  it 'refuses conflicting approved knowledge instead of choosing an answer' do
    create(:knowledge_item, account: account, source_kind: :faq, question: 'Do you offer audits?', answer: 'Yes.')
    create(:knowledge_item, account: account, source_kind: :faq, question: 'Do you offer audits?', answer: 'No.')

    result = described_class.new(account: account, question: 'Do you offer audits?').perform

    expect(result).to be_refused
    expect(result.answer).to be_nil
    expect(result.refusal_reason).to eq('conflicting_knowledge')
  end

  it 'refuses sensitive questions for Human Operator review' do
    result = described_class.new(account: account, question: 'Can you give legal advice about our contract?').perform

    expect(result).to be_refused
    expect(result.answer).to be_nil
    expect(result.refusal_reason).to eq('sensitive_question')
  end

  it 'refuses angry questions for Human Operator review' do
    result = described_class.new(account: account, question: 'I am furious about this terrible service').perform

    expect(result).to be_refused
    expect(result.answer).to be_nil
    expect(result.refusal_reason).to eq('angry_question')
  end
end
