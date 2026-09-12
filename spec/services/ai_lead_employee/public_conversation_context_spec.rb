# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::PublicConversationContext do
  it 'returns only bounded recent public messages through the triggering message' do
    conversation = create(:conversation)
    7.times do |index|
      create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                       message_type: :incoming, content: "Public #{index}")
    end
    create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                     message_type: :outgoing, private: true, content: 'Private operator note')
    trigger = create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                               message_type: :incoming, content: 'Correction: I need coaching.')
    create(:message, conversation: conversation, account: conversation.account, inbox: conversation.inbox,
                     message_type: :outgoing, content: 'Later message')

    context = described_class.new(conversation: conversation, through_message: trigger).to_a

    expect(context.length).to eq(6)
    expect(context.last).to eq(role: 'lead', content: 'Correction: I need coaching.')
    expect(context).not_to include(include(content: 'Private operator note'))
    expect(context).not_to include(include(content: 'Later message'))
  end
end
