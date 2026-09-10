# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::QualificationService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:business_prompt) { 'What type of business do you run?' }

  def ask_business
    displayed = AiLeadEmployee::QualificationQuestionLocalizer::SWAHILI_QUESTION_TRANSLATIONS.fetch(business_prompt)
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :outgoing, content: displayed,
                     additional_attributes: { ai_lead_employee: { qualification: { next_question: business_prompt } } })
  end

  def receive(content)
    message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                               message_type: :incoming, sender: conversation.contact, content: content)
    described_class.new(conversation: conversation, incoming_message: message).perform
  end

  ['Tell me about your course.', 'Please explain your business.', 'Thanks. Tell me about your course.'].each do |request|
    it "does not create or replay business evidence from #{request.inspect}", :aggregate_failures do
      ask_business
      result = receive(request)

      expect(result.qualification.evidence_snapshot).not_to have_key('business_type')
      expect(result.next_question).to eq(business_prompt)
      expect(conversation.qualification_evidences.where(signal: :business_type)).to be_empty
      create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                       message_type: :outgoing, content: 'Our course covers business automation.')
      replayed = receive('Thanks.')
      expect(replayed.qualification.evidence_snapshot).not_to have_key('business_type')
      expect(conversation.qualification_evidences.where(signal: :business_type)).to be_empty
    end
  end

  it 'preserves a genuine descriptive business answer and advances' do
    ask_business
    result = receive('Bookkeeping')

    expect(result.qualification.evidence_snapshot['business_type']).to include('polarity' => 'positive', 'value' => 'bookkeeping')
    expect(result.next_question).to eq('What problem are you trying to solve right now?')
  end

  it 'preserves a genuine descriptive problem answer and advances' do
    create(:qualification_question, account: account, signal: :problem, prompt: 'Your problem?', position: 1)
    create(:qualification_question, account: account, signal: :budget, prompt: 'Your budget?', position: 2)
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                     message_type: :outgoing, content: 'Your problem?')
    result = receive('Customer acquisition')

    expect(result.qualification.evidence_snapshot['problem']).to include('polarity' => 'positive')
    expect(result.next_question).to eq('Your budget?')
  end

  it 'retains explicit business evidence from another clause in an informational request' do
    ask_business
    result = receive('Tell me about your course. I run a salon.')

    expect(result.qualification.evidence_snapshot['business_type']).to include('polarity' => 'positive', 'value' => 'salon')
    expect(result.next_question).to eq('What problem are you trying to solve right now?')
  end
end
