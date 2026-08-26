# frozen_string_literal: true

FactoryBot.define do
  factory :lead_follow_up do
    account
    contact { create(:contact, account: account) }
    conversation { create(:conversation, account: account, contact: contact) }
    lead_qualification { create(:lead_qualification, account: account, contact: contact) }
    status { :pending }
    stage { :incomplete_qualification }
    attempt_number { 1 }
    question_text { 'What budget range have you set aside?' }
    content { 'Just following up on this so I can help properly: What budget range have you set aside?' }
    control_version { conversation.control_version }
    scheduled_at { 1.day.from_now }
  end
end
