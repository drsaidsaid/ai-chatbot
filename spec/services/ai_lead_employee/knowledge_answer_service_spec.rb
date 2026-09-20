# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::KnowledgeAnswerService do
  let(:account) { create(:account) }

  let(:selected_offer) do
    AiLeadEmployee::Offer.create!(
      account: account,
      name: 'Growth coaching',
      currency: 'USD',
      enabled: true,
      configuration: {
        'qualification_mode' => 'disabled',
        'next_step' => { 'kind' => 'answer_only' },
        'questions' => [],
        'budget_ranges' => [],
        'rules' => [],
        'score_weights' => {},
        'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
      }
    )
  end

  it 'answers from approved knowledge for the same Business Account' do
    item = create(:knowledge_item, account: account, question: 'Do you offer consulting?', answer: 'Yes, we offer consulting.')

    result = described_class.new(account: account, question: 'Do you offer consulting?').perform

    expect(result).to be_answered
    expect(result.answer).to eq('Yes, we offer consulting.')
    expect(result.sources).to contain_exactly(
      include(id: item.id, title: item.title, source_kind: 'faq', status: 'verified')
    )
  end

  it 'uses shared and selected Offer knowledge while excluding another Offer' do
    shared = create(:knowledge_item, account: account, question: 'What support is included?', answer: 'Email support is included.')
    selected = create(
      :knowledge_item,
      account: account,
      question: 'How does coaching support work?',
      answer: 'Growth coaching includes a weekly session.',
      metadata: { 'source_reference' => 'growth-coaching-support-v1', 'offer_ids' => [selected_offer.id] }
    )
    other_offer = AiLeadEmployee::Offer.create!(account: account, name: 'Audit', currency: 'USD', enabled: true)
    create(
      :knowledge_item,
      account: account,
      question: 'How does audit support work?',
      answer: 'The audit includes a written report.',
      metadata: { 'source_reference' => 'audit-support-v1', 'offer_ids' => [other_offer.id] }
    )

    shared_result = described_class.new(account: account, offer: selected_offer, question: shared.question).perform
    selected_result = described_class.new(account: account, offer: selected_offer, question: selected.question).perform
    excluded_result = described_class.new(account: account, offer: selected_offer, question: 'How does audit support work?').perform

    expect(shared_result.answer).to eq(shared.answer)
    expect(selected_result.answer).to eq(selected.answer)
    expect(excluded_result).to be_refused
  end

  it 'does not answer from approved knowledge in a different configured language' do
    create(
      :knowledge_item,
      account: account,
      question: 'What support is included?',
      answer: 'English support details.',
      metadata: { 'language' => 'english' }
    )

    result = described_class.new(account: account, question: 'Msaada gani unapatikana?', language: :swahili).perform

    expect(result).to be_refused
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

  it 'answers general business context from a published Knowledge Document' do
    document = create(
      :knowledge_document,
      account: account,
      title: 'Everything about Online Profits',
      body: 'Online Profits helps service businesses with CRM automation and marketing systems.'
    )

    result = described_class.new(account: account, question: 'Do you help with CRM automation?').perform

    expect(result).to be_answered
    expect(result.answer).to include('CRM automation')
    expect(result.sources).to contain_exactly(
      include(id: document.id, title: document.title, source_kind: 'document', status: 'verified')
    )
  end

  it 'excludes a published Document scoped to another Offer' do
    other_offer = AiLeadEmployee::Offer.create!(account: account, name: 'Audit', currency: 'USD', enabled: true)
    create(
      :knowledge_document,
      account: account,
      title: 'Audit delivery',
      body: 'Audit delivery includes a written report and review call.',
      general_question_access: false,
      offer_ids: [other_offer.id]
    )

    result = described_class.new(account: account, offer: selected_offer, question: 'What does audit delivery include?').perform

    expect(result).to be_refused
  end

  it 'answers from a published Document scoped to the selected Offer' do
    document = create(
      :knowledge_document,
      account: account,
      title: 'Growth coaching delivery',
      body: 'Growth coaching delivery includes a weekly review call.',
      general_question_access: false,
      offer_ids: [selected_offer.id]
    )

    result = described_class.new(
      account: account, offer: selected_offer, question: 'What does growth coaching delivery include?'
    ).perform

    expect(result.answer).to include('weekly review call')
    expect(result.sources).to contain_exactly(include(id: document.id, offer_id: selected_offer.id))
  end

  it 'uses a selected Offer document as semantic context for a multilingual suitability question' do
    document = create(
      :knowledge_document,
      account: account,
      title: 'Online Profits coaching',
      body: 'Online Profits helps founders build marketing systems and improve follow-up.',
      general_question_access: false,
      offer_ids: [selected_offer.id]
    )

    result = described_class.new(
      account: account,
      offer: selected_offer,
      question: 'Je, programu yenu inaweza kunisaidia? Tafadhali nijibu kwa Kiswahili.',
      language: :swahili
    ).perform

    expect(result).to be_answered
    expect(result.answer).to include('Online Profits helps founders')
    expect(result.sources).to contain_exactly(include(id: document.id, offer_id: selected_offer.id))
  end

  it 'recognizes a Swahili help question with a question suffix as selected Offer suitability' do
    document = create(
      :knowledge_document,
      account: account,
      title: 'Online Profits programme',
      body: 'Online Profits is a 12-month programme where business experts help founders build an online business.',
      general_question_access: false,
      offer_ids: [selected_offer.id]
    )

    result = described_class.new(
      account: account,
      offer: selected_offer,
      question: 'Nataka kujua zaidi kuhusu huduma mnazotoa. Mnaweza kunisaidiaje kujenga biashara mtandaoni?',
      language: :swahili
    ).perform

    expect(result).to be_answered
    expect(result.sources).to contain_exactly(include(id: document.id, offer_id: selected_offer.id))
  end

  it 'does not use selected Offer document fallback for an unknown detail question' do
    create(
      :knowledge_document,
      account: account,
      title: 'Online Profits coaching',
      body: 'Online Profits helps founders build marketing systems and improve follow-up.',
      general_question_access: false,
      offer_ids: [selected_offer.id]
    )

    result = described_class.new(
      account: account,
      offer: selected_offer,
      question: 'Does the programme include weekend delivery?'
    ).perform

    expect(result).to be_refused
    expect(result.refusal_reason).to eq('no_approved_knowledge')
  end

  it 'refuses semantic selected Offer fallback when multiple scoped documents are eligible' do
    create(
      :knowledge_document,
      account: account,
      title: 'Coaching overview',
      body: 'This coaching helps founders with marketing systems.',
      general_question_access: false,
      offer_ids: [selected_offer.id]
    )
    create(
      :knowledge_document,
      account: account,
      title: 'Operations overview',
      body: 'This service helps founders with delivery operations.',
      general_question_access: false,
      offer_ids: [selected_offer.id]
    )

    result = described_class.new(
      account: account,
      offer: selected_offer,
      question: 'Je, programu yenu inaweza kunisaidia? Tafadhali nijibu kwa Kiswahili.',
      language: :swahili
    ).perform

    expect(result).to be_refused
    expect(result.refusal_reason).to eq('no_approved_knowledge')
  end

  it 'accepts standard language aliases in approved metadata' do
    item = create(
      :knowledge_item,
      account: account,
      question: 'Msaada gani unapatikana?',
      answer: 'Tunatoa msaada kwa barua pepe.',
      metadata: { 'language' => 'sw', 'source_reference' => 'sw-support-v1' }
    )

    result = described_class.new(account: account, question: item.question, language: :swahili).perform

    expect(result.answer).to eq(item.answer)
  end

  it 'does not use Documents for exact sensitive claims without an Approved Answer' do
    create(
      :knowledge_document,
      account: account,
      body: 'Refunds are available for 30 days and setup pricing starts at $20.'
    )

    result = described_class.new(account: account, question: 'What is your refund policy?').perform

    expect(result).to be_refused
    expect(result.refusal_reason).to eq('sensitive_question')
  end

  it 'uses Approved Answers over Documents for exact sensitive claims' do
    create(:knowledge_document, account: account, body: 'Setup pricing starts at $10.')
    create(:knowledge_item, account: account, source_kind: :pricing, question: 'What is your setup price?', answer: 'Setup starts at $20.')

    result = described_class.new(account: account, question: 'What is your setup price?').perform

    expect(result.answer).to eq('Setup starts at $20.')
    expect(result.sources.first[:source_kind]).to eq('pricing')
  end

  it 'uses the selected Offer published commercial revision instead of conflicting price knowledge' do
    admin = create(:user, account: account, role: :administrator)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: selected_offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: selected_offer, expected_version: term.draft_version, editor: admin)
    create(
      :knowledge_item,
      account: account,
      source_kind: :pricing,
      question: 'What is the price of growth coaching?',
      answer: 'An old document says USD 900.',
      metadata: { 'offer_ids' => [selected_offer.id] }
    )

    result = described_class.new(
      account: account,
      offer: selected_offer.reload,
      question: 'What is the price of growth coaching?'
    ).perform

    expect(result.answer).to include('USD 1250.00')
    expect(result.answer).not_to include('USD 900')
    expect(result.sources).to contain_exactly(include(type: 'offer_commercial_terms', offer_id: selected_offer.id))
  end

  it 'blocks a price quotation when the selected Offer has no published commercial revision' do
    create(
      :knowledge_item,
      account: account,
      source_kind: :pricing,
      question: 'What is the price of growth coaching?',
      answer: 'An old document says USD 900.',
      metadata: { 'offer_ids' => [selected_offer.id] }
    )

    result = described_class.new(
      account: account,
      offer: selected_offer,
      question: 'What is the price of growth coaching?'
    ).perform

    expect(result).to be_refused
    expect(result.refusal_reason).to eq('no_published_price')
    expect(result.answer).to be_nil
  end

  it 'keeps actual platform pricing separate while preserving Offer authority in mixed budget questions' do
    admin = create(:user, account: account, role: :administrator)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: selected_offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: selected_offer, expected_version: term.draft_version, editor: admin)
    create(
      :knowledge_item,
      account: account,
      source_kind: :pricing,
      question: 'Does my USD 500 budget cover the price?',
      answer: 'An old answer says the Offer costs USD 500.',
      metadata: { 'offer_ids' => [selected_offer.id] }
    )

    platform_result = described_class.new(
      account: account, offer: selected_offer.reload, question: 'What is the platform subscription price?'
    ).perform
    budget_result = described_class.new(
      account: account, offer: selected_offer, question: 'Does my USD 500 budget cover the price?'
    ).perform

    expect(platform_result.answer).to be_nil
    expect(platform_result).to be_refused
    expect(budget_result.answer).to include('USD 1250.00')
    expect(budget_result.answer).not_to include('costs USD 500')
    expect(budget_result.sources).to contain_exactly(include(type: 'offer_commercial_terms'))
  end

  it 'does not let stale knowledge override a selected Offer whose name includes plan or subscription' do
    selected_offer.update!(name: 'Growth Plan Subscription')
    admin = create(:user, account: account, role: :administrator)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: selected_offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: selected_offer, expected_version: term.draft_version, editor: admin)
    create(
      :knowledge_item,
      account: account,
      source_kind: :pricing,
      question: 'What is the Growth Plan Subscription price?',
      answer: 'The old price was USD 20.',
      metadata: { 'offer_ids' => [selected_offer.id] }
    )

    result = described_class.new(
      account: account, offer: selected_offer.reload, question: 'What is the Growth Plan Subscription price?'
    ).perform

    expect(result.answer).to include('USD 1250.00')
    expect(result.answer).not_to include('USD 20')
    expect(result.sources).to contain_exactly(include(type: 'offer_commercial_terms'))
  end

  it 'keeps Offer authority when a price question explicitly excludes the platform subscription' do
    admin = create(:user, account: account, role: :administrator)
    term = AiLeadEmployee::CommercialTerms.save_draft!(
      offer: selected_offer,
      attributes: { amount: '1250.00', currency: 'USD', quote_required: false, timezone: 'UTC' }
    )
    AiLeadEmployee::CommercialTerms.publish!(offer: selected_offer, expected_version: term.draft_version, editor: admin)
    create(
      :knowledge_item,
      account: account,
      source_kind: :pricing,
      question: 'What is the course price?',
      answer: 'The old course price was USD 900.',
      metadata: { 'offer_ids' => [selected_offer.id] }
    )

    result = described_class.new(
      account: account,
      offer: selected_offer.reload,
      question: 'What is the course price, excluding the platform subscription?'
    ).perform

    expect(result.answer).to include('USD 1250.00')
    expect(result.answer).not_to include('USD 900')
    expect(result.sources).to contain_exactly(include(type: 'offer_commercial_terms'))
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
