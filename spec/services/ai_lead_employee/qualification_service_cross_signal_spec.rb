# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::QualificationService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:business_prompt) { 'What type of business do you run?' }

  before do
    create(:qualification_question, account: account, signal: :budget, prompt: 'Your budget?', position: 1)
    create(:qualification_question, account: account, signal: :business_type, prompt: business_prompt, position: 2)
  end

  def receive(content)
    message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                               message_type: :incoming, sender: conversation.contact, content: content)
    [message, described_class.new(conversation: conversation, incoming_message: message).perform]
  end

  def ask_business
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :outgoing, content: business_prompt,
                     additional_attributes: { ai_lead_employee: { qualification: { next_question: business_prompt } } })
  end

  it 'preserves a budget correction and source history without consuming the unanswered business question', :aggregate_failures do
    original_message, initial = receive('My budget is TZS 500000.')
    expect(initial.qualification.evidence_snapshot['budget']).to include('polarity' => 'positive', 'currency' => 'TZS', 'amount_minor' => 50_000_000)
    expect(initial.next_question).to eq(business_prompt)
    ask_business
    correction_message, corrected = receive('Correction, I have no budget.')

    expect(corrected.qualification.evidence_snapshot['budget']).to include('polarity' => 'negative', 'message_id' => correction_message.id)
    expect(corrected.qualification).not_to be_highly_qualified
    expect(corrected.qualification.evidence_snapshot).not_to have_key('business_type')
    expect(corrected.next_question).to eq(business_prompt)
    history = conversation.qualification_evidences.where(signal: :budget).order(:id)
    expect(history.count).to eq(2)
    expect(history.first.message_id).to eq(original_message.id)
    expect(history.first.superseded_by).to eq(history.last)
    expect(history.last.message_id).to eq(correction_message.id)
  end

  it 'still completes the business question when the Lead supplies a genuine descriptive answer' do
    receive('My budget is TZS 500000.')
    ask_business
    _message, result = receive('Bookkeeping')

    expect(result.qualification.evidence_snapshot['business_type']).to include('polarity' => 'positive', 'value' => 'bookkeeping')
    expect(result.next_question).to be_nil
  end
end
