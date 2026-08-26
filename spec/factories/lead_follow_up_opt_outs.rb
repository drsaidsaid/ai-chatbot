# frozen_string_literal: true

FactoryBot.define do
  factory :lead_follow_up_opt_out do
    account
    contact { create(:contact, account: account) }
    conversation { create(:conversation, account: account, contact: contact) }
    reason { 'lead_requested_opt_out' }
    opted_out_at { Time.current }
  end
end
