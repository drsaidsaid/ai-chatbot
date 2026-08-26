# frozen_string_literal: true

FactoryBot.define do
  factory :human_review_request do
    account
    conversation { create(:conversation, account: account) }
    lead_message { create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming) }
    reason { :no_approved_knowledge }
    status { :open }
    question { lead_message.content }
    alert_recipients { [] }
    alert_deliveries { [] }
  end
end
