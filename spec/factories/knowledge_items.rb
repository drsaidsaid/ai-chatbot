# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_item do
    account
    title { 'Consulting FAQ' }
    question { 'Do you offer consulting?' }
    answer { 'Yes, we offer consulting for qualified businesses.' }
    source_kind { :faq }
    status { :approved }
    approved_at { Time.current }
    sequence(:metadata) { |n| { source_reference: "factory-source-reference-#{n}" } }
  end
end
