# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OptOutService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account, control_state: :ai_active) }
  let(:qualification) { create(:lead_qualification, account: account, contact: conversation.contact, follow_up_state: :nurture) }

  it 'records consent withdrawal and cancels pending follow-ups for clear opt-out language' do
    follow_up = create(
      :lead_follow_up,
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification
    )
    message = create(
      :message,
      account: account,
      inbox: conversation.inbox,
      conversation: conversation,
      sender: conversation.contact,
      content: 'STOP'
    )

    opt_out = described_class.new(conversation: conversation, message: message).perform

    expect(opt_out).to be_present
    expect(opt_out.reason).to eq('lead_requested_opt_out')
    expect(follow_up.reload).to be_cancelled
    expect(follow_up.cancellation_reason).to eq('follow_up_opted_out')
    expect(qualification.reload.follow_up_state).to eq('closed')
  end

  it 'ignores ordinary replies' do
    message = create(
      :message,
      account: account,
      inbox: conversation.inbox,
      conversation: conversation,
      sender: conversation.contact,
      content: 'No, my budget is not ready yet'
    )

    expect(described_class.new(conversation: conversation, message: message).perform).to be_nil
    expect(LeadFollowUpOptOut.count).to eq(0)
  end
end
