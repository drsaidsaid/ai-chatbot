# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Subscriptions::PurchasePreview do
  let(:account) { create(:account, settings: { reporting_timezone: 'Africa/Dar_es_Salaam' }) }
  let(:starter) do
    create(:ai_service_plan, code: 'starter', name: 'Starter', included_ai_replies: 10,
                             monthly_price: 100_000, top_up_price: 75_000, top_up_ai_replies: 5)
  end
  let!(:growth) do
    create(:ai_service_plan, code: 'growth', name: 'Growth', included_ai_replies: 30,
                             monthly_price: 250_000, top_up_price: 90_000, top_up_ai_replies: 5)
  end
  let!(:subscription) do
    create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10,
                             top_up_ai_replies: 5, reporting_timezone: 'Africa/Dar_es_Salaam')
  end

  def consume_replies(count)
    count.times do
      usage = AiLeadEmployee::ReplyAllowance.reserve!(
        intent: create(:ai_orchestration_intent, account: account),
        at: Time.zone.parse('2026-09-15T08:00:00Z')
      )
      usage.update!(status: :settled, settled_at: Time.zone.parse('2026-09-15T08:01:00Z'))
    end
  end

  it 'previews the full-cycle upgrade difference and exact balance without changing the entitlement', :aggregate_failures do
    consume_replies(12)
    original_renewal = subscription.renews_at

    preview = described_class.new(account: account, plan: growth, purpose: :upgrade,
                                  at: Time.zone.parse('2026-09-15T09:00:00Z')).perform

    expect(preview).to include(
      purpose: 'upgrade', amount_due: 150_000, currency: 'TZS', renews_at: original_renewal,
      used_ai_replies: 12, awaiting_delivery_ai_replies: 0, current_remaining_ai_replies: 3,
      resulting_included_ai_replies: 30, resulting_included_ai_replies_remaining: 18,
      resulting_top_up_ai_replies_remaining: 5, resulting_ai_replies_remaining: 23
    )
    expect(preview.fetch(:unit_price_comparison)).to include(
      comparison_plan_name: 'Growth', top_up_unit_price: 15_000,
      savings_percentage: 44.4
    )
    expect(preview.dig(:unit_price_comparison, :included_unit_price)).to be_within(BigDecimal('0.0001')).of(BigDecimal('8333.3333'))
    expect(subscription.reload).to have_attributes(
      ai_service_plan: starter, included_ai_replies: 10, top_up_ai_replies: 5, renews_at: original_renewal
    )
  end

  it 'previews an approved top-up after current included and purchased usage', :aggregate_failures do
    create(:ai_service_plan, code: 'not-an-upgrade', name: 'Lower price', included_ai_replies: 20,
                             monthly_price: 90_000)
    consume_replies(12)

    preview = described_class.new(account: account, plan: starter, purpose: :top_up,
                                  at: Time.zone.parse('2026-09-15T09:00:00Z')).perform

    expect(preview).to include(
      amount_due: 75_000, requested_ai_replies: 5, current_remaining_ai_replies: 3,
      resulting_included_ai_replies_remaining: 0, resulting_top_up_ai_replies_remaining: 8,
      resulting_ai_replies_remaining: 8
    )
    expect(preview.dig(:unit_price_comparison, :comparison_plan_name)).to eq('Growth')
    expect(AiLeadEmployee::AiSubscriptionRequest.where(account: account)).to be_empty
  end

  it 'rejects an ambiguous cross-currency or lower-value plan transition' do
    usd_plan = create(:ai_service_plan, currency: 'USD', included_ai_replies: 50, monthly_price: 300)

    expect do
      described_class.new(account: account, plan: usd_plan, purpose: :upgrade).perform
    end.to raise_error(described_class::InvalidPreview, /keep currency/)

    expect do
      described_class.new(account: account, plan: starter, purpose: :upgrade).perform
    end.to raise_error(described_class::InvalidPreview, /increase both/)
  end

  it 'preserves purchased extras but requires renewal before another top-up or upgrade when the subscription expired' do
    travel_to Time.zone.parse('2026-10-12T00:00:01Z') do
      expect do
        described_class.new(account: account, plan: starter, purpose: :top_up).perform
      end.to raise_error(described_class::InvalidPreview, /Renew the subscription first/)

      expect(subscription.reload.top_up_ai_replies).to eq(5)
    end
  end

  it 'makes the customer review a fresh preview when usage changes before the request is recorded' do
    preview = described_class.new(account: account, plan: growth, purpose: :upgrade).perform
    signature = described_class.signature_for(account: account, preview: preview)
    AiLeadEmployee::ReplyAllowance.reserve!(intent: create(:ai_orchestration_intent, account: account))

    expect do
      AiLeadEmployee::Subscriptions::RequestService.new(
        account: account, requested_by: create(:user, account: account, role: :administrator),
        plan: growth, purpose: :upgrade, preview_signature: signature
      ).perform
    end.to raise_error(AiLeadEmployee::Subscriptions::RequestService::InvalidRequest, /balance changed/)

    expect(AiLeadEmployee::AiSubscriptionRequest.where(account: account)).to be_empty
  end
end
