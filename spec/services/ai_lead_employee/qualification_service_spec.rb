# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::QualificationService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'asks the first unanswered enabled question and skips facts already provided' do
    create(:qualification_question, account: account, signal: :problem, prompt: 'What problem should we solve?', position: 1)
    create(:qualification_question, account: account, signal: :budget, prompt: 'What budget have you set aside?', position: 2)
    message = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'I need help getting more leads for my agency.'
    )

    result = described_class.new(conversation: conversation, incoming_message: message).perform

    expect(result.qualification).to be_low_qualified
    expect(result.next_question).to eq('What budget have you set aside?')
    expect(result.qualification.evidence_snapshot).to include('problem', 'business_type')
  end

  it 'requires pain budget urgency and decision authority before marking a Lead highly qualified' do
    {
      problem: 'need more sales',
      budget: '$2000',
      urgency: 'urgent',
      decision_authority: 'owner'
    }.each do |signal, value|
      create(:qualification_evidence, account: account, contact: conversation.contact, signal: signal, value: { 'value' => value })
    end

    result = described_class.new(conversation: conversation).perform

    expect(result.qualification).to be_highly_qualified
    expect(result.qualification.follow_up_state).to eq('human_review')
    expect(result.qualification.missing_signals).to include('business_type', 'lead_volume', 'contact_details')
    expect(result.next_question).to eq('What type of business do you run?')
  end

  it 'keeps human corrections current and stores the configuration version used for re-evaluation' do
    account.update!(settings: account.settings.merge('qualification_config_version' => 4))
    extracted = create(:qualification_evidence, account: account, contact: conversation.contact, signal: :budget, value: { 'value' => '$50' })
    human = described_class.record_human_evidence!(
      contact: conversation.contact,
      conversation: conversation,
      user: create(:user, account: account),
      signal: :budget,
      value: '$2500'
    )

    result = described_class.new(conversation: conversation).perform

    expect(extracted.reload.superseded_by).to eq(human)
    expect(result.qualification.evidence_snapshot.dig('budget', 'value')).to eq('$2500')
    expect(result.qualification.configuration_version).to eq(4)
  end

  it 'stores each quality decision without replacing prior decision history' do
    create(:qualification_evidence, account: account, contact: conversation.contact, signal: :problem, value: { 'value' => 'need more leads' })

    described_class.new(conversation: conversation).perform
    described_class.new(conversation: conversation).perform

    expect(conversation.contact.lead_qualification.lead_qualification_decisions.count).to eq(2)
  end

  it 'lets returning Leads be reclassified from newer extracted evidence for the same signal' do
    create(:qualification_evidence, account: account, contact: conversation.contact, signal: :budget, value: { 'value' => '$50' })
    message = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'My budget is $2500'
    )

    result = described_class.new(conversation: conversation, incoming_message: message).perform

    expect(result.qualification).to be_low_qualified
    expect(result.qualification.evidence_snapshot.dig('budget', 'value')).to eq('$2500')
    expect(QualificationEvidence.where(contact: conversation.contact, signal: :budget).current.count).to eq(1)
  end

  it 'keeps human evidence authoritative over later extracted evidence' do
    described_class.record_human_evidence!(
      contact: conversation.contact,
      conversation: conversation,
      user: create(:user, account: account),
      signal: :budget,
      value: '$3000'
    )
    message = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'Actually my budget is $50'
    )

    result = described_class.new(conversation: conversation, incoming_message: message).perform

    expect(result.qualification.evidence_snapshot.dig('budget', 'value')).to eq('$3000')
  end

  it 'uses configured budget ranges when deciding whether a Lead is unqualified' do
    create(:qualification_budget_range, account: account, min_cents: 100_000, max_cents: nil)
    create(:qualification_evidence, account: account, contact: conversation.contact, signal: :budget, value: { 'value' => '$500' })

    result = described_class.new(conversation: conversation).perform

    expect(result.qualification).to be_unqualified
  end
end
