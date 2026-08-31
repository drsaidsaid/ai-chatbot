# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::QualificationService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'uses an existing WhatsApp profile name without asking for it again' do
    conversation.contact.update!(name: 'Asha Mushi')

    result = described_class.new(conversation: conversation).perform

    expect(result.qualification.evidence_snapshot.dig('name', 'value')).to eq('Asha Mushi')
    expect(result.next_question).to eq('What type of business do you run?')
  end

  it 'asks for a name when the contact still has a phone-number placeholder' do
    conversation.contact.update!(name: '+255712345678', phone_number: '+255712345678')
    message = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'Hello'
    )

    result = described_class.new(conversation: conversation, incoming_message: message).perform

    expect(conversation.contact.reload.name).to eq('+255712345678')
    expect(result.next_question).to eq('What is your name?')
  end

  it 'saves a valid answer to the name question on the canonical Contact' do
    conversation.contact.update!(name: '+255712345678', phone_number: '+255712345678')
    create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content: "Welcome.\n\nWhat is your name?"
    )
    answer = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      message_type: :incoming,
      content: 'My name is Neema Juma'
    )

    result = described_class.new(conversation: conversation, incoming_message: answer).perform

    expect(conversation.contact.reload.name).to eq('Neema Juma')
    expect(result.qualification.evidence_snapshot.dig('name', 'value')).to eq('Neema Juma')
    expect(result.next_question).to eq('What type of business do you run?')
  end

  it 'does not save a greeting as the name after asking the name question' do
    conversation.contact.update!(name: '+255712345678', phone_number: '+255712345678')
    create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content: 'What is your name?'
    )
    greeting = create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      message_type: :incoming,
      content: 'Hello'
    )

    result = described_class.new(conversation: conversation, incoming_message: greeting).perform

    expect(conversation.contact.reload.name).to eq('+255712345678')
    expect(result.qualification.evidence_snapshot).not_to have_key('name')
    expect(result.next_question).to eq('What is your name?')
  end

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
    operator = create(:user, account: account)
    human = described_class.record_human_evidence!(
      contact: conversation.contact,
      conversation: conversation,
      user: operator,
      signal: :budget,
      value: '$2500'
    )

    result = described_class.new(conversation: conversation).perform

    expect(extracted.reload.superseded_by).to eq(human)
    expect(result.qualification.evidence_snapshot.dig('budget', 'value')).to eq('$2500')
    expect(result.qualification.evidence_snapshot.dig('budget', 'source_reference')).to include(
      'type' => 'human_edit',
      'user_id' => operator.id,
      'conversation_id' => conversation.id
    )
    expect(result.qualification.configuration_version).to eq(4)
    expect(Audited::Audit.where(auditable: conversation.contact).last.audited_changes).to include(
      'ai_lead_employee_action' => 'qualification_evidence_corrected',
      'signal' => 'budget',
      'value' => '$2500'
    )
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

  it 'extracts returning Lead evidence from prior persisted messages when no evidence exists yet' do
    create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'I run an agency and need more leads.'
    )
    create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'I am the owner, this is urgent, and my budget is $2500.'
    )

    result = described_class.new(conversation: conversation).perform

    expect(result.qualification).to be_highly_qualified
    expect(result.qualification.evidence_snapshot).to include('business_type', 'problem', 'urgency', 'budget', 'decision_authority')
    expect(result.next_question).to eq('How many leads or inquiries do you handle each month?')
  end

  it 'does not treat stale required evidence as current for highly qualified decisions' do
    {
      problem: 'need more sales',
      budget: '$2000',
      urgency: 'urgent',
      decision_authority: 'owner'
    }.each do |signal, value|
      create(
        :qualification_evidence,
        account: account,
        contact: conversation.contact,
        signal: signal,
        value: { 'value' => value },
        observed_at: 45.days.ago
      )
    end

    result = described_class.new(conversation: conversation).perform

    expect(result.qualification).not_to be_highly_qualified
    expect(result.qualification.missing_signals).to include('problem', 'budget', 'urgency', 'decision_authority')
    expect(result.next_question).to eq('What type of business do you run?')
  end

  it 'does not recreate stale evidence from old persisted Lead messages on repeated evaluation' do
    create(
      :message,
      account: account,
      conversation: conversation,
      inbox: conversation.inbox,
      sender: conversation.contact,
      content: 'I am the owner, this is urgent, and my budget is $2500.',
      created_at: 45.days.ago
    )

    first_result = described_class.new(conversation: conversation).perform
    second_result = described_class.new(conversation: conversation).perform

    expect(first_result.qualification).to be_unknown
    expect(second_result.qualification).to be_unknown
    expect(QualificationEvidence.where(contact: conversation.contact).where.not(signal: :name)).to be_empty
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
