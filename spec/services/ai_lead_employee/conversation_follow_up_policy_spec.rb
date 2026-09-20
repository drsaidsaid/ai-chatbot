# frozen_string_literal: true

require 'active_support/all'

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/language_detector'
require_relative '../../../app/services/ai_lead_employee/conversation_follow_up_policy'

RSpec.describe AiLeadEmployee::ConversationFollowUpPolicy do
  let(:classification_type) { Struct.new(:intent, :language, keyword_init: true) }
  let(:qualification_type) { Struct.new(:qualification_mode, :next_question, keyword_init: true) }
  let(:english_question) { 'What result do you need?' }

  it 'never turns the actual Swahili greeting into a missing-revenue interview' do
    result = described_class.new(
      classification: classification_type.new(intent: :greeting, language: :swahili),
      qualification_result: qualification_type.new(qualification_mode: 'enabled', next_question: 'What is your monthly revenue?')
    ).perform

    expect(result).to be_nil
  end

  it 'never appends a configured question after an unknown-answer acknowledgement' do
    result = described_class.new(
      classification: classification_type.new(intent: :business_question, language: :english),
      qualification_result: qualification_type.new(qualification_mode: 'enabled', next_question: english_question),
      reply_kind: :review_acknowledgment
    ).perform

    expect(result).to be_nil
  end

  it 'omits an untranslated configured prompt from a local Swahili qualification reply' do
    result = described_class.new(
      classification: classification_type.new(intent: :qualification_answer, language: :swahili),
      qualification_result: qualification_type.new(qualification_mode: 'enabled', next_question: english_question)
    ).perform

    expect(result).to be_nil
  end

  it 'keeps one same-language prompt for a normal eligible qualification answer' do
    question = 'Je, unahitaji matokeo gani?'
    result = described_class.new(
      classification: classification_type.new(intent: :qualification_answer, language: :swahili),
      qualification_result: qualification_type.new(qualification_mode: 'enabled', next_question: question)
    ).perform

    expect(result).to eq(question)
  end

  it 'does not restore a prompt for disabled or not-configured qualification' do
    [:disabled, nil].each do |mode|
      result = described_class.new(
        classification: classification_type.new(intent: :qualification_answer, language: :english),
        qualification_result: qualification_type.new(qualification_mode: mode, next_question: english_question)
      ).perform

      expect(result).to be_nil
    end
  end
end
