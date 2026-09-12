# frozen_string_literal: true

FactoryBot.define do
  factory :ai_service_plan, class: 'AiLeadEmployee::AiServicePlan' do
    sequence(:code) { |n| "plan-#{n}" }
    name { 'Managed AI' }
    version { 1 }
    status { 'published' }
    currency { 'TZS' }
    monthly_price { 250_000 }
    included_ai_replies { 1000 }
    top_up_price { 75_000 }
    top_up_ai_replies { 5 }
    payment_instructions { 'Pay the approved invoice and share its reference.' }
    published_at { Time.current }
  end
end
