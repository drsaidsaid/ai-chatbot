# frozen_string_literal: true

FactoryBot.define do
  factory :ai_orchestration_intent, class: 'AiLeadEmployee::OrchestrationIntent' do
    account
    conversation { create(:conversation, account: account) }
    triggering_message do
      create(:message,
             account: account,
             inbox: conversation.inbox,
             conversation: conversation,
             message_type: :incoming)
    end
    observed_control_version { conversation.control_version }
    sequence(:idempotency_key) do |n|
      "ai-orchestration/#{account.id}/#{conversation.id}/#{triggering_message.id}/#{observed_control_version}/#{n}"
    end
  end
end
