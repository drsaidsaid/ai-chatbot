# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::ConversationIntentClassifier do
  it 'classifies a Swahili language-support question as safe conversation' do
    result = described_class.new(message: 'unaongea kiswahili?').perform

    expect(result.intent).to eq(:language_question)
    expect(result.language).to eq(:swahili)
    expect(result).to be_safe_conversation
    expect(result).not_to be_requires_approved_knowledge
  end

  it 'classifies Swahili and English greetings as safe conversation' do
    swahili = described_class.new(message: 'habari').perform
    english = described_class.new(message: 'Hello there').perform

    expect(swahili.intent).to eq(:greeting)
    expect(swahili.language).to eq(:swahili)
    expect(swahili).to be_safe_conversation
    expect(english.intent).to eq(:greeting)
    expect(english.language).to eq(:english)
    expect(english).to be_safe_conversation
  end

  it 'classifies lead-detail statements as qualification answers' do
    result = described_class.new(message: 'I run an online course business and I need more qualified leads.').perform

    expect(result.intent).to eq(:qualification_answer)
    expect(result.language).to eq(:english)
    expect(result).to be_safe_conversation
  end

  it 'classifies Swahili requests for offer details as business questions' do
    result = described_class.new(message: 'naomba maelezo kuhusu Online Profits').perform

    expect(result.intent).to eq(:business_question)
    expect(result.language).to eq(:swahili)
    expect(result).to be_requires_approved_knowledge
    expect(result).not_to be_safe_conversation
  end

  it 'classifies controlled claims as risky questions' do
    result = described_class.new(message: 'What is your refund policy and guarantee?').perform

    expect(result.intent).to eq(:risky_question)
    expect(result.language).to eq(:english)
    expect(result).to be_risky
    expect(result).to be_requires_approved_knowledge
  end

  it 'classifies short acknowledgements as generic safe conversation' do
    result = described_class.new(message: 'sawa').perform

    expect(result.intent).to eq(:generic_safe)
    expect(result.language).to eq(:swahili)
    expect(result).to be_safe_conversation
  end
end
