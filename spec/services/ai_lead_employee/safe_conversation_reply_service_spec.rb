# frozen_string_literal: true

require 'active_support/all'

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/language_detector'
require_relative '../../../app/services/ai_lead_employee/conversation_intent_classifier'
require_relative '../../../app/services/ai_lead_employee/conversation_follow_up_policy'
require_relative '../../../app/services/ai_lead_employee/safe_conversation_reply_service'

RSpec.describe AiLeadEmployee::SafeConversationReplyService do
  let(:result_type) { Struct.new(:next_question, :qualification_mode, keyword_init: true) }

  it 'sets a polite boundary for an unrelated question without a sales question' do
    reply = described_class.new(
      message: 'Who won the football match?',
      refusal_reason: nil,
      qualification_result: result_type.new(next_question: 'What is your budget?', qualification_mode: 'enabled')
    ).perform

    expect(reply).to eq('I can help with questions about this business and its Offers.')
  end

  it 'asks a model-free clarification when Business scope is unresolved' do
    classification = AiLeadEmployee::ConversationIntentClassifier::Result.new(
      intent: :scope_clarification,
      language: :english
    )
    reply = described_class.new(
      message: 'Can I book a flight?',
      refusal_reason: nil,
      qualification_result: nil,
      classification: classification
    ).perform

    expect(reply).to eq('Are you asking about this business or one of its Offers?')
  end

  it 'asks the scope clarification in Swahili' do
    classification = AiLeadEmployee::ConversationIntentClassifier::Result.new(
      intent: :scope_clarification,
      language: :swahili
    )
    reply = described_class.new(
      message: 'Je, unauliza kuhusu huduma gani?',
      refusal_reason: nil,
      qualification_result: nil,
      classification: classification
    ).perform

    expect(reply).to eq('Je, unauliza kuhusu biashara hii au mojawapo ya Ofa zake?')
  end

  it 'truthfully acknowledges an unknown business question without promising a callback or forcing qualification' do
    reply = described_class.new(
      message: 'Do you integrate with a system that is not documented?',
      refusal_reason: 'no_approved_knowledge',
      qualification_result: result_type.new(next_question: 'What is your budget?', qualification_mode: 'enabled')
    ).perform

    expect(reply).to eq('I do not have an approved answer for that yet. I have recorded your question for the team to review.')
  end

  it 'asks one configured question after a qualification answer' do
    reply = described_class.new(
      message: 'I run a coaching business.',
      refusal_reason: nil,
      qualification_result: result_type.new(next_question: 'What result do you need?', qualification_mode: 'enabled')
    ).perform

    expect(reply).to eq("Thanks for those details.\n\nWhat result do you need?")
  end

  it 'does not restore legacy qualification questions when Offer qualification is absent' do
    reply = described_class.new(
      message: 'Hello',
      refusal_reason: nil,
      qualification_result: result_type.new(next_question: 'What type of business do you run?', qualification_mode: nil)
    ).perform

    expect(reply).to eq('Hello. How can I help with this business today?')
  end

  it 'does not append an untranslated revenue question to a Swahili greeting with a selected Offer' do
    reply = described_class.new(
      message: 'Habari yako',
      refusal_reason: nil,
      qualification_result: result_type.new(
        next_question: 'What is your monthly revenue?', qualification_mode: 'enabled'
      )
    ).perform

    expect(reply).to eq('Habari. Ninaweza kusaidia kuhusu biashara hii leo?')
  end

  it 'sets a consulting boundary for unsupported personalized strategy' do
    reply = described_class.new(
      message: 'Build a marketing strategy for my company.',
      refusal_reason: 'no_approved_knowledge',
      qualification_result: result_type.new(next_question: 'What result do you need?', qualification_mode: 'enabled')
    ).perform

    expected = 'I cannot create a personalized strategy from unapproved information. ' \
               'I have recorded your question for the team to review.'
    expect(reply).to eq(expected)
  end
end
