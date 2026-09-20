# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::ConversationIntentClassifier, type: :service do
  let(:account) { create(:account) }

  it 'keeps a standalone Swahili wellbeing greeting in safe conversation and replies in Swahili' do
    classification = described_class.new(message: 'Ukoje?', account: account).perform
    reply = AiLeadEmployee::SafeConversationReplyService.new(
      message: 'Ukoje?', classification: classification, qualification_result: nil
    ).perform

    expect(classification).to have_attributes(intent: :greeting, language: :swahili)
    expect(reply).to eq('Habari. Ninaweza kusaidia kuhusu biashara hii leo?')
  end

  it 'keeps an account-context English wellbeing greeting safe' do
    result = described_class.new(message: 'Hello, how are you?', account: account).perform

    expect(result).to have_attributes(intent: :greeting, language: :english)
    expect(result).to be_safe_conversation
  end
end
