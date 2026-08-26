# frozen_string_literal: true

FactoryBot.define do
  factory :lead_qualification do
    account
    contact { create(:contact, account: account) }
    quality { :unknown }
    follow_up_state { :no_follow_up }
    score { 0 }
    reasons { [] }
    missing_signals { [] }
    evidence_snapshot { {} }
    configuration_version { 1 }
    last_evaluated_at { Time.current }
  end
end
