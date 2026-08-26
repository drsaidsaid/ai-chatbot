# frozen_string_literal: true

FactoryBot.define do
  factory :qualification_budget_range do
    account
    label { '$500 - $1,000' }
    min_cents { 50_000 }
    max_cents { 100_000 }
    position { 1 }
    enabled { true }
  end
end
