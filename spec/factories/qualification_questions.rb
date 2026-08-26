# frozen_string_literal: true

FactoryBot.define do
  factory :qualification_question do
    account
    signal { :problem }
    prompt { 'What problem are you trying to solve right now?' }
    position { 1 }
    enabled { true }
    metadata { {} }
  end
end
