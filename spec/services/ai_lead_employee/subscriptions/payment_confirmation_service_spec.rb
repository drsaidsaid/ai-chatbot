# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Subscriptions::PaymentConfirmationService do
  let(:account) { create(:account, settings: { reporting_timezone: 'Africa/Dar_es_Salaam' }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:platform_app) { create(:platform_app) }
  let(:starter) { create(:ai_service_plan, code: 'starter', included_ai_replies: 10, monthly_price: 100_000) }
  let(:growth) { create(:ai_service_plan, code: 'growth', included_ai_replies: 30, monthly_price: 250_000) }

  def request_for(plan:, purpose:)
    AiLeadEmployee::Subscriptions::RequestService.new(
      account: account, requested_by: admin, plan: plan, purpose: purpose
    ).perform
  end

  def confirm(request, reference:, amount:, units: nil)
    described_class.new(
      account: account, request: request, platform_app: platform_app,
      attributes: { payment_reference: reference, amount: amount, currency: request.currency,
                    confirmed_at: '2026-09-12T08:00:00Z', granted_ai_replies: units }
    ).perform
  end

  it 'keeps the renewal boundary and existing usage when a paid upgrade replaces the included allowance' do
    subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10,
                                            top_up_ai_replies: 2)
    12.times do
      intent = create(:ai_orchestration_intent, account: account)
      described_class_name = AiLeadEmployee::ReplyAllowance
      described_class_name.reserve!(intent: intent, at: Time.zone.parse('2026-09-15 08:00:00 UTC'))
                          .update!(status: :settled, settled_at: Time.current)
    end
    original_renewal = subscription.renews_at
    request = request_for(plan: growth, purpose: 'upgrade')

    confirmation = confirm(request, reference: 'UPGRADE-1', amount: 150_000)

    expect(confirmation.purpose).to eq('upgrade')
    expect(subscription.reload).to have_attributes(
      ai_service_plan: growth, included_ai_replies: 30, top_up_ai_replies: 2, renews_at: original_renewal
    )
    expect(AiLeadEmployee::ReplyAllowance.summary(account: account, at: Time.zone.parse('2026-09-15 09:00:00 UTC'))).to include(
      used_ai_replies: 12, remaining_ai_replies: 20, top_up_ai_replies_remaining: 2
    )
  end

  it 'uses only the published top-up price and allowance approved for the current plan' do
    create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    request = request_for(plan: starter, purpose: 'top_up')

    expect(request).to have_attributes(quoted_amount: 75_000, requested_ai_replies: 5)
    confirmation = confirm(request, reference: 'TOPUP-1', amount: 75_000, units: 5)

    expect(confirmation).to have_attributes(amount: 75_000, granted_ai_replies: 5)
    expect(AiLeadEmployee::AiSubscription.find_by!(account: account).top_up_ai_replies).to eq(5)
  end

  it 'rejects a platform confirmation that changes an approved top-up package' do
    create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    request = request_for(plan: starter, purpose: 'top_up')

    expect do
      confirm(request, reference: 'TOPUP-OVERRIDE', amount: 75_000, units: 50)
    end.to raise_error(described_class::InvalidConfirmation, /approved package/)
  end

  it 'records an early renewal without resetting the current month usage' do
    subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    usage = AiLeadEmployee::ReplyAllowance.reserve!(
      intent: create(:ai_orchestration_intent, account: account),
      at: Time.zone.parse('2026-09-12T07:30:00Z')
    )
    usage.update!(status: :settled, settled_at: Time.zone.parse('2026-09-12T07:31:00Z'))
    original_period = subscription.period_started_at
    request = request_for(plan: starter, purpose: 'renewal')

    confirm(request, reference: 'RENEWAL-1', amount: 100_000)

    expect(subscription.reload).to have_attributes(
      period_started_at: original_period,
      renews_at: Time.zone.parse('2026-10-12T00:00:00Z'),
      paid_through_at: Time.zone.parse('2026-11-12T00:00:00Z')
    )
    expect(AiLeadEmployee::ReplyAllowance.summary(account: account)[:used_ai_replies]).to eq(1)
  end

  it 'rejects a reused payment reference when entitlement details differ' do
    first_request = request_for(plan: starter, purpose: 'new_subscription')
    confirm(first_request, reference: 'BANK-ONE', amount: 100_000)
    second_request = request_for(plan: growth, purpose: 'upgrade')

    expect do
      confirm(second_request, reference: 'BANK-ONE', amount: 150_000)
    end.to raise_error(described_class::InvalidConfirmation, /already used/)
  end

  it 'rejects a stale pending upgrade after another request changes the current plan' do
    create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    first_request = request_for(plan: growth, purpose: 'upgrade')
    stale_request = request_for(plan: growth, purpose: 'upgrade')
    confirm(first_request, reference: 'UPGRADE-FIRST', amount: 150_000)

    expect do
      confirm(stale_request, reference: 'UPGRADE-STALE', amount: 150_000)
    end.to raise_error(described_class::InvalidConfirmation, /Subscription changed/)

    expect(AiLeadEmployee::AiSubscription.find_by!(account: account).ai_service_plan).to eq(growth)
    expect(stale_request.reload).to be_pending
  end

  it 'rejects a same-plan request after the entitlement state changes' do
    subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    request = request_for(plan: starter, purpose: 'top_up')
    subscription.update!(top_up_ai_replies: 1)

    expect do
      confirm(request, reference: 'TOPUP-STALE', amount: 75_000, units: 5)
    end.to raise_error(described_class::InvalidConfirmation, /Subscription changed/)

    expect(request.reload).to be_pending
  end

  it 'does not create payment requests for a subscription awaiting review' do
    create(:ai_subscription, account: account, ai_service_plan: starter, status: :review_required)

    expect do
      request_for(plan: starter, purpose: 'renewal')
    end.to raise_error(AiLeadEmployee::Subscriptions::RequestService::InvalidRequest, /not active/)
  end

  it 'rolls back both payment evidence and entitlement when the verified amount is wrong' do
    request = request_for(plan: starter, purpose: 'new_subscription')

    expect do
      confirm(request, reference: 'WRONG-AMOUNT', amount: 99_999)
    end.to raise_error(described_class::InvalidConfirmation, /amount/)

    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: account)).to be_empty
    expect(AiLeadEmployee::AiSubscription.where(account: account)).to be_empty
    expect(request.reload).to be_pending
  end

  it 'rejects a payment confirmation timestamp in the future' do
    request = request_for(plan: starter, purpose: 'new_subscription')

    expect do
      described_class.new(
        account: account, request: request, platform_app: platform_app,
        attributes: { payment_reference: 'FUTURE', amount: 100_000, currency: request.currency,
                      confirmed_at: 1.day.from_now.iso8601 }
      ).perform
    end.to raise_error(described_class::InvalidConfirmation, /cannot be in the future/)

    expect(request.reload).to be_pending
  end
end
