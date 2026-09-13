# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::Subscriptions::PaymentConfirmationService do
  let(:account) { create(:account, settings: { reporting_timezone: 'Africa/Dar_es_Salaam' }) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:platform_app) { create(:platform_app, finance_operations_enabled: true) }
  let(:starter) { create(:ai_service_plan, code: 'starter', included_ai_replies: 10, monthly_price: 100_000) }
  let(:growth) { create(:ai_service_plan, code: 'growth', included_ai_replies: 30, monthly_price: 250_000) }

  def request_for(plan:, purpose:)
    preview_signature = if purpose.to_s.in?(%w[top_up upgrade])
                          preview = AiLeadEmployee::Subscriptions::PurchasePreview.new(
                            account: account, plan: plan, purpose: purpose
                          ).perform
                          AiLeadEmployee::Subscriptions::PurchasePreview.signature_for(account: account, preview: preview)
                        end
    AiLeadEmployee::Subscriptions::RequestService.new(
      account: account, requested_by: admin, plan: plan, purpose: purpose,
      preview_signature: preview_signature
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

  it 'supports multiple same-cycle upgrades using only each full plan-price difference' do
    enterprise = create(:ai_service_plan, code: 'enterprise', included_ai_replies: 50, monthly_price: 400_000)
    subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10,
                                            top_up_ai_replies: 3)
    original_renewal = subscription.renews_at

    first = request_for(plan: growth, purpose: 'upgrade')
    expect(first.quoted_amount).to eq(150_000)
    confirm(first, reference: 'UPGRADE-GROWTH', amount: 150_000)

    second = request_for(plan: enterprise, purpose: 'upgrade')
    expect(second.quoted_amount).to eq(150_000)
    confirm(second, reference: 'UPGRADE-ENTERPRISE', amount: 150_000)

    expect(subscription.reload).to have_attributes(
      ai_service_plan: enterprise, included_ai_replies: 50, top_up_ai_replies: 3, renews_at: original_renewal
    )
  end

  it 'serializes concurrent usage and upgrade without losing or multiplying capacity' do
    subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    9.times do
      usage = AiLeadEmployee::ReplyAllowance.reserve!(intent: create(:ai_orchestration_intent, account: account))
      usage.update!(status: :settled, settled_at: Time.current)
    end
    request = request_for(plan: growth, purpose: 'upgrade')
    intent = create(:ai_orchestration_intent, account: account)
    gate = Queue.new
    workers = [
      -> { AiLeadEmployee::ReplyAllowance.reserve!(intent: intent) },
      -> { confirm(request, reference: 'CONCURRENT-UPGRADE', amount: 150_000) }
    ].map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          operation.call
        rescue StandardError => e
          e
        end
      end
    end
    2.times { gate << true }

    expect(workers).to all(satisfy { |worker| worker.join(10) == worker })
    errors = workers.map(&:value).grep(StandardError)
    expect(errors).to all(be_a(described_class::InvalidConfirmation).and(have_attributes(message: /Subscription changed/)))
    if request.reload.pending?
      fresh_request = request_for(plan: growth, purpose: 'upgrade')
      confirm(fresh_request, reference: 'CONCURRENT-UPGRADE-REVIEWED', amount: 150_000)
    end
    expect(subscription.reload.ai_service_plan).to eq(growth)
    expect(AiLeadEmployee::ReplyAllowance.summary(account: account)).to include(
      reserved_ai_replies: 1, used_ai_replies: 9, remaining_ai_replies: 20
    )
  end

  it 'allows only one stale snapshot to win during concurrent renewal and upgrade confirmations' do
    subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10)
    renewal = request_for(plan: starter, purpose: 'renewal')
    upgrade = request_for(plan: growth, purpose: 'upgrade')
    gate = Queue.new
    operations = [
      -> { confirm(renewal, reference: 'CONCURRENT-RENEWAL', amount: 100_000) },
      -> { confirm(upgrade, reference: 'CONCURRENT-UPGRADE-2', amount: 150_000) }
    ].map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          operation.call
        rescue StandardError => e
          e
        end
      end
    end
    2.times { gate << true }

    expect(operations).to all(satisfy { |worker| worker.join(10) == worker })
    outcomes = operations.map(&:value)
    expect(outcomes.grep(AiLeadEmployee::SubscriptionPaymentConfirmation).one?).to be(true)
    expect(outcomes.grep(described_class::InvalidConfirmation).one?).to be(true)
    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: account).count).to eq(1)
    expect(subscription.reload.ai_service_plan).to be_in([starter, growth])
  end

  it 'carries unused purchased extras across a paid renewal and monthly allowance reset' do
    subscription = nil
    travel_to Time.zone.parse('2026-09-20T08:00:00Z') do
      subscription = create(:ai_subscription, account: account, ai_service_plan: starter, included_ai_replies: 10,
                                              top_up_ai_replies: 5)
      12.times do
        usage = AiLeadEmployee::ReplyAllowance.reserve!(intent: create(:ai_orchestration_intent, account: account))
        usage.update!(status: :settled, settled_at: Time.current)
      end
      renewal = request_for(plan: starter, purpose: 'renewal')
      confirm(renewal, reference: 'CARRY-RENEWAL', amount: 100_000)
    end
    travel_to Time.zone.parse('2026-10-12T00:00:01Z') do
      summary = AiLeadEmployee::ReplyAllowance.summary(account: account)

      expect(summary).to include(
        included_ai_replies: 10, used_ai_replies: 0, top_up_ai_replies_remaining: 3,
        remaining_ai_replies: 13
      )
    end
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

  it 'rejects an unprivileged platform app without mutating payment or entitlement state' do
    request = request_for(plan: starter, purpose: 'new_subscription')
    unprivileged_app = create(:platform_app, finance_operations_enabled: false)

    expect do
      described_class.new(
        account: account, request: request, platform_app: unprivileged_app,
        attributes: { payment_reference: 'UNAUTHORISED', amount: 100_000, currency: request.currency,
                      confirmed_at: Time.current.iso8601 }
      ).perform
    end.to raise_error(described_class::InvalidConfirmation, /finance authority/)

    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: account)).to be_empty
    expect(AiLeadEmployee::AiSubscription.where(account: account)).to be_empty
    expect(request.reload).to be_pending
  end

  it 'rechecks finance authority at execution after the platform app is revoked' do
    request = request_for(plan: starter, purpose: 'new_subscription')
    service = described_class.new(
      account: account, request: request, platform_app: platform_app,
      attributes: { payment_reference: 'REVOKED', amount: 100_000, currency: request.currency,
                    confirmed_at: Time.current.iso8601 }
    )
    platform_app.update!(finance_operations_enabled: false)

    expect { service.perform }.to raise_error(described_class::InvalidConfirmation, /finance authority/)

    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: account)).to be_empty
    expect(AiLeadEmployee::AiSubscription.where(account: account)).to be_empty
    expect(request.reload).to be_pending
  end

  it 'does not disclose an existing confirmation to a now-unprivileged platform app' do
    request = request_for(plan: starter, purpose: 'new_subscription')
    confirm(request, reference: 'EXISTING-AUTHORISED', amount: 100_000)
    platform_app.update!(finance_operations_enabled: false)

    expect do
      confirm(request, reference: 'EXISTING-AUTHORISED', amount: 100_000)
    end.to raise_error(described_class::InvalidConfirmation, /finance authority/)
  end
end
