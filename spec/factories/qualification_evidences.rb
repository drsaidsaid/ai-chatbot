# frozen_string_literal: true

FactoryBot.define do
  factory :qualification_evidence do
    account
    contact { create(:contact, account: account) }
    signal { :problem }
    value { { 'value' => 'need more leads' } }
    source { :extracted }
    observed_at { Time.current }
  end
end
