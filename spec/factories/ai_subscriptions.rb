# frozen_string_literal: true

FactoryBot.define do
  factory :ai_subscription, class: 'AiLeadEmployee::AiSubscription' do
    account
    ai_service_plan
    status { 'active' }
    reporting_timezone { account.reporting_timezone.presence || 'UTC' }
    period_started_at { Time.zone.parse('2026-09-12 00:00:00 UTC') }
    renews_at { Time.zone.parse('2026-10-12 00:00:00 UTC') }
    paid_through_at { renews_at }
    renewal_anchor_day { 12 }
    included_ai_replies { ai_service_plan.included_ai_replies }
    top_up_ai_replies { 0 }
  end
end
