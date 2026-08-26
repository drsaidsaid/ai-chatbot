# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::FollowUpScheduler do
  let(:account) do
    create(
      :account,
      settings: {
        'ai_lead_employee_follow_up' => {
          'enabled' => true,
          'delay_minutes' => 60,
          'max_attempts' => 3,
          'qualified_second_follow_up_enabled' => true
        }
      }
    )
  end
  let(:conversation) { create(:conversation, account: account, control_state: :ai_active, control_version: 2) }
  let(:question) do
    create(:qualification_question, account: account, signal: :budget, prompt: 'What budget range have you set aside?', position: 1)
  end

  it 'schedules one follow-up for an incomplete qualification using the unanswered question' do
    qualification = create(
      :lead_qualification,
      account: account,
      contact: conversation.contact,
      quality: :low_qualified,
      follow_up_state: :nurture,
      missing_signals: ['budget']
    )
    result = AiLeadEmployee::QualificationService::Result.new(qualification: qualification, next_question: question.prompt)

    expect do
      described_class.new(conversation: conversation, qualification_result: result).perform
    end.to have_enqueued_job(AiLeadEmployee::FollowUpDeliveryJob)

    follow_up = LeadFollowUp.last
    expect(follow_up).to be_incomplete_qualification
    expect(follow_up.attempt_number).to eq(1)
    expect(follow_up.question_text).to eq(question.prompt)
    expect(follow_up.control_version).to eq(2)
  end

  it 'schedules an optional second follow-up for qualified Leads when configured' do
    qualification = create(
      :lead_qualification,
      account: account,
      contact: conversation.contact,
      quality: :qualified,
      follow_up_state: :nurture,
      missing_signals: ['contact_details']
    )
    result = AiLeadEmployee::QualificationService::Result.new(qualification: qualification, next_question: 'What is the best phone number?')

    described_class.new(conversation: conversation, qualification_result: result).perform

    expect(LeadFollowUp.order(:attempt_number).pluck(:stage, :attempt_number)).to eq(
      [['qualified_nurture', 1], ['qualified_nurture', 2]]
    )
  end

  it 'cancels pending follow-ups when the Lead opted out' do
    qualification = create(:lead_qualification, account: account, contact: conversation.contact, quality: :low_qualified)
    existing = create(:lead_follow_up, account: account, contact: conversation.contact, conversation: conversation, lead_qualification: qualification)
    create(:lead_follow_up_opt_out, account: account, contact: conversation.contact, conversation: conversation)
    result = AiLeadEmployee::QualificationService::Result.new(qualification: qualification, next_question: question.prompt)

    described_class.new(conversation: conversation, qualification_result: result).perform

    expect(existing.reload).to be_cancelled
    expect(existing.cancellation_reason).to eq('follow_up_opted_out')
    expect(LeadFollowUp.pending.count).to eq(0)
  end

  it 'does not duplicate the logical follow-up attempt when scheduling is retried' do
    qualification = create(
      :lead_qualification,
      account: account,
      contact: conversation.contact,
      quality: :low_qualified,
      follow_up_state: :nurture,
      missing_signals: ['budget']
    )
    result = AiLeadEmployee::QualificationService::Result.new(qualification: qualification, next_question: question.prompt)

    2.times { described_class.new(conversation: conversation, qualification_result: result).perform }

    expect(LeadFollowUp.where(account: account, contact: conversation.contact, stage: :incomplete_qualification).count).to eq(1)
  end

  it 'cancels pending follow-ups when the conversation is resolved' do
    qualification = create(:lead_qualification, account: account, contact: conversation.contact, quality: :low_qualified)
    follow_up = create(
      :lead_follow_up,
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification
    )

    conversation.resolved!

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('conversation_resolved')
  end

  it 'cancels pending follow-ups when booking closes the lead follow-up state' do
    qualification = create(:lead_qualification, account: account, contact: conversation.contact, quality: :qualified, follow_up_state: :nurture)
    follow_up = create(
      :lead_follow_up,
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification
    )

    qualification.update!(follow_up_state: :call_booked)

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('follow_up_state_call_booked')
  end
end
