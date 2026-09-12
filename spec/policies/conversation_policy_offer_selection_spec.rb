# frozen_string_literal: true

require 'rails_helper'

# Conversation Offer selection policy.
RSpec.describe ConversationPolicy do
  it 'does not grant Offer mutation to a bot that can read the Conversation' do
    account = create(:account)
    bot = create(:agent_bot, account: account)
    conversation = create(:conversation, account: account)
    policy = described_class.new({ user: bot, account: account, account_user: nil }, conversation)

    expect(policy.show?).to be(true)
    expect(policy.select_offer?).to be(false)
  end
end
