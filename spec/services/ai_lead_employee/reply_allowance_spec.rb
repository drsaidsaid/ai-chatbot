# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::ReplyAllowance do
  let(:account) { create(:account) }
  let!(:subscription) do
    create(:ai_subscription, account: account, included_ai_replies: 1,
                             period_started_at: Time.zone.parse('2026-09-01 21:00:00 UTC'),
                             renews_at: Time.zone.parse('2026-10-01 21:00:00 UTC'), renewal_anchor_day: 1)
  end

  def intent_for(target_account = account)
    create(:ai_orchestration_intent, account: target_account)
  end

  def delivery_for(message, usage)
    message.whatsapp_outbound_delivery || Whatsapp::OutboundDelivery.create!(
      account: message.account,
      conversation: message.conversation,
      message: message,
      ai_reply_usage: usage,
      observed_control_version: message.conversation.control_version
    )
  end

  def terminal_partial_reply(second_accepted: false)
    intent = intent_for
    usage = described_class.reserve!(intent: intent)
    messages = reply_messages(intent, usage)
    deliveries = messages.map { |message| delivery_for(message, usage) }
    described_class.register_deliveries!(usage: usage, messages: messages)
    project_provider_status(deliveries.first, messages.first, 'sent', 'wamid.partial.1')
    if second_accepted
      project_provider_status(deliveries.second, messages.second, 'failed', 'wamid.partial.2')
    else
      deliveries.second.update!(state: :failed, failure_code: 'provider_rejected')
    end
    [usage, messages, deliveries]
  end

  def reply_messages(intent, usage)
    Array.new(2) do
      create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                       message_type: :outgoing,
                       additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    end
  end

  def project_provider_status(delivery, message, status, provider_message_id)
    delivery.update!(state: :accepted, accepted_at: Time.current, provider_message_id: provider_message_id)
    Whatsapp::MessageStatusProjector.new(
      message: message.reload, status: { status: status, timestamp: Time.current.to_i.to_s }
    ).perform
  end

  it 'reserves one unit idempotently for one logical orchestration reply' do
    intent = intent_for

    first = nil
    expect do
      first = described_class.reserve!(intent: intent, at: Time.zone.parse('2026-09-12 08:00:00 UTC'))
    end.to have_enqueued_job(AiLeadEmployee::SubscriptionAlertDeliveryJob).once
    replay = described_class.reserve!(intent: intent, at: Time.zone.parse('2026-09-12 08:01:00 UTC'))

    expect(replay.id).to eq(first.id)
    expect(AiLeadEmployee::AiReplyUsage.where(account: account).count).to eq(1)
    expect(described_class.summary(account: account, at: Time.zone.parse('2026-09-12 08:02:00 UTC'))).to include(
      used_ai_replies: 0, reserved_ai_replies: 1, remaining_ai_replies: 0, automation_allowed: false
    )
  end

  it 'serializes competing messages so the final unit cannot be reserved twice' do
    intents = [intent_for, intent_for]
    gate = Queue.new
    outcomes = intents.map do |intent|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          described_class.reserve!(intent: intent, at: Time.zone.parse('2026-09-12 08:00:00 UTC'))
        rescue described_class::Exhausted => e
          e
        end
      end
    end
    2.times { gate << true }
    outcomes = outcomes.map(&:value)

    expect(outcomes.count { |outcome| outcome.is_a?(AiLeadEmployee::AiReplyUsage) }).to eq(1)
    expect(outcomes.count { |outcome| outcome.is_a?(described_class::Exhausted) }).to eq(1)
    expect(AiLeadEmployee::AiReplyUsage.where(account: account).reserved.count).to eq(1)
    expect(subscription.reload.action_required_alerted_at).to be_present
    expect(subscription.alerts.open.allowance_exhausted.count).to eq(1)
  end

  it 'resets included usage on the account calendar boundary and carries purchased extras forward' do
    subscription.update!(reporting_timezone: 'Africa/Dar_es_Salaam', top_up_ai_replies: 1,
                         paid_through_at: Time.zone.parse('2026-11-01 21:00:00 UTC'))
    old_intent = intent_for
    described_class.reserve!(intent: old_intent, at: Time.zone.parse('2026-09-30 20:59:59 UTC'))
                   .update!(status: :settled, settled_at: Time.zone.parse('2026-09-30 20:59:59 UTC'))

    new_intent = intent_for
    usage = described_class.reserve!(intent: new_intent, at: Time.zone.parse('2026-10-01 21:00:00 UTC'))

    expect(usage).to be_included
    expect(subscription.reload.period_started_at).to eq(Time.zone.parse('2026-10-01 21:00:00 UTC'))
    expect(described_class.summary(account: account, at: Time.zone.parse('2026-10-01 21:01:00 UTC'))).to include(
      used_ai_replies: 0, reserved_ai_replies: 1, remaining_ai_replies: 1, top_up_ai_replies_remaining: 1
    )
  end

  it 'returns to a month-end billing anchor after a shorter calendar month' do
    subscription.update!(period_started_at: Time.zone.parse('2027-01-31 07:00:00 UTC'),
                         renews_at: Time.zone.parse('2027-02-28 07:00:00 UTC'),
                         paid_through_at: Time.zone.parse('2027-03-31 07:00:00 UTC'), renewal_anchor_day: 31)

    described_class.summary(account: account, at: Time.zone.parse('2027-03-01 07:00:00 UTC'))

    expect(subscription.reload).to have_attributes(
      period_started_at: Time.zone.parse('2027-02-28 07:00:00 UTC'),
      renews_at: Time.zone.parse('2027-03-31 07:00:00 UTC')
    )
  end

  it 'does not grant a new monthly allowance before manual renewal is confirmed' do
    subscription.update!(period_started_at: Time.zone.parse('2026-08-12 00:00:00 UTC'),
                         renews_at: Time.zone.parse('2026-09-12 00:00:00 UTC'),
                         paid_through_at: Time.zone.parse('2026-09-12 00:00:00 UTC'))

    summary = described_class.summary(account: account, at: Time.zone.parse('2026-09-12 00:00:00 UTC'))

    expect(summary).to include(status: 'renewal_due', remaining_ai_replies: 0, automation_allowed: false,
                               automation_paused_reason: 'subscription_renewal_due')
    expect do
      described_class.reserve!(intent: intent_for, at: Time.zone.parse('2026-09-12 00:00:00 UTC'))
    end.to raise_error(described_class::Exhausted, 'subscription_renewal_due')
    expect(subscription.alerts.open.subscription_renewal_due.count).to eq(1)
  end

  it 'keeps unknown delivery reserved, settles accepted delivery once, and releases confirmed failure' do
    intent = intent_for
    usage = described_class.reserve!(intent: intent, at: Time.zone.parse('2026-09-12 08:00:00 UTC'))
    message = create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                               message_type: :outgoing,
                               additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    delivery = delivery_for(message, usage)
    described_class.register_deliveries!(usage: usage, messages: [message])

    delivery.update!(state: :unknown, failure_code: 'acceptance_unknown')
    expect(usage.reload).to be_reserved

    delivery.update!(state: :accepted, accepted_at: Time.current, provider_message_id: 'wamid.confirmed')
    expect(usage.reload).to be_reserved
    Whatsapp::MessageStatusProjector.new(
      message: message.reload, status: { status: 'sent', timestamp: Time.current.to_i.to_s }
    ).perform
    expect(usage.reload).to be_settled

    subscription.update!(paid_through_at: Time.zone.parse('2026-11-01 21:00:00 UTC'))
    second_usage = described_class.reserve!(intent: intent_for, at: Time.zone.parse('2026-10-02 08:00:00 UTC'))
    described_class.reconcile!(usage: second_usage, outcome: 'confirmed_not_sent',
                               platform_app: create(:platform_app, finance_operations_enabled: true),
                               reason: 'provider_lookup_not_found')
    expect(second_usage.reload).to be_released
  end

  it 'closes a confirmed terminal partial failure without billing and releases its capacity exactly once' do
    usage, _messages, deliveries = terminal_partial_reply
    _first_delivery, second_delivery = deliveries

    expect(usage.reload).to have_attributes(
      status: 'partially_delivered', settled_at: nil, released_at: nil,
      reconciliation_reason: 'partial_delivery_requires_reconciliation'
    )
    expect(described_class.summary(account: account)).to include(
      used_ai_replies: 0, reserved_ai_replies: 0, reconciliation_required_ai_replies: 1,
      remaining_ai_replies: 0, automation_allowed: false
    )
    expect(second_delivery.retry_for?(create(:user, account: account, role: :administrator))).to be(false)

    operator = create(:platform_app, finance_operations_enabled: true)
    released_at = nil
    expect do
      described_class.reconcile!(usage: usage, outcome: 'confirmed_partial_failure', platform_app: operator,
                                 reason: 'operator_confirmed_terminal_partial_failure')
      released_at = usage.reload.released_at
      described_class.reconcile!(usage: usage, outcome: 'confirmed_partial_failure', platform_app: operator,
                                 reason: 'duplicate_operator_submission')
    end.not_to(change { AiLeadEmployee::AiReplyUsage.where(account: account).count })

    expect(usage.reload).to have_attributes(
      status: 'partial_failure_closed', settled_at: nil, released_at: released_at,
      reconciliation_reason: 'operator_confirmed_terminal_partial_failure', reconciled_by_platform_app_id: operator.id
    )
    expect(described_class.summary(account: account)).to include(
      used_ai_replies: 0, reserved_ai_replies: 0, reconciliation_required_ai_replies: 0,
      remaining_ai_replies: 1, automation_allowed: true
    )
    expect(AiLeadEmployee::AiReplyUsage.where(account: account).settled.count).to eq(0)
  end

  it 'preserves sent evidence and permanently blocks replay when partial failure is closed' do
    usage, messages, deliveries = terminal_partial_reply
    first_delivery, second_delivery = deliveries
    sent_evidence = messages.first.reload.content_attributes.slice(
      'whatsapp_provider_status', 'whatsapp_delivery_timestamp'
    )

    described_class.reconcile!(
      usage: usage, outcome: 'confirmed_partial_failure',
      platform_app: create(:platform_app, finance_operations_enabled: true), reason: 'terminal_provider_lookup'
    )

    expect(
      messages.first.reload.content_attributes.slice('whatsapp_provider_status', 'whatsapp_delivery_timestamp')
    ).to eq(sent_evidence)
    expect(first_delivery.reload.provider_message_id).to eq('wamid.partial.1')
    expect(second_delivery.reload).to have_attributes(state: 'failed', failure_code: 'provider_rejected')
    expect(second_delivery.retry_for?(create(:user, account: account, role: :administrator))).to be(false)
    expect(described_class.reserve!(intent: intent_for)).to be_reserved
  end

  it 'keeps a manually closed partial failure terminal when a contradictory late receipt arrives' do
    usage, messages, deliveries = terminal_partial_reply(second_accepted: true)
    described_class.reconcile!(
      usage: usage, outcome: 'confirmed_partial_failure',
      platform_app: create(:platform_app, finance_operations_enabled: true), reason: 'terminal_provider_lookup'
    )

    Whatsapp::MessageStatusProjector.new(
      message: messages.second.reload, status: { status: 'sent', timestamp: 5.minutes.from_now.to_i.to_s }
    ).perform

    expect(usage.reload).to have_attributes(
      status: 'partial_failure_closed', settled_at: nil, reconciliation_reason: 'terminal_provider_lookup'
    )
    expect(deliveries.second.retry_for?(create(:user, account: account, role: :administrator))).to be(false)
    expect(described_class.summary(account: account)).to include(remaining_ai_replies: 1, used_ai_replies: 0)
  end

  it 'keeps settlement billable when the late final receipt wins before manual partial closure' do
    usage, messages, deliveries = terminal_partial_reply(second_accepted: true)
    Whatsapp::MessageStatusProjector.new(
      message: messages.second.reload, status: { status: 'sent', timestamp: 5.minutes.from_now.to_i.to_s }
    ).perform

    described_class.reconcile!(
      usage: usage, outcome: 'confirmed_partial_failure',
      platform_app: create(:platform_app, finance_operations_enabled: true), reason: 'late_operator_submission'
    )

    expect(usage.reload).to be_settled
    expect(usage.released_at).to be_nil
    expect(deliveries.second.retry_for?(create(:user, account: account, role: :administrator))).to be(false)
    expect(described_class.summary(account: account)).to include(remaining_ai_replies: 0, used_ai_replies: 1)
  end

  it 'serializes a late final receipt against manual partial closure without duplicating allowance' do
    subscription.update!(included_ai_replies: 2)
    usage, messages, deliveries = terminal_partial_reply(second_accepted: true)
    operator = create(:platform_app, finance_operations_enabled: true)
    gate = Queue.new
    workers = [
      lambda {
        described_class.reconcile!(usage: usage, outcome: 'confirmed_partial_failure', platform_app: operator,
                                   reason: 'terminal_provider_lookup')
      },
      lambda {
        Whatsapp::MessageStatusProjector.new(
          message: messages.second.reload, status: { status: 'sent', timestamp: 5.minutes.from_now.to_i.to_s }
        ).perform
      }
    ].map do |action|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          action.call
        end
      end
    end
    2.times { gate << true }
    workers.each(&:value)

    expect(usage.reload.status).to be_in(%w[settled partial_failure_closed])
    expect(deliveries.second.retry_for?(create(:user, account: account, role: :administrator))).to be(false)
    available = described_class.summary(account: account).fetch(:remaining_ai_replies)
    successful = 3.times.count do
      described_class.reserve!(intent: intent_for)
      true
    rescue described_class::Exhausted
      false
    end
    expect(successful).to eq(available)
    expect(AiLeadEmployee::AiReplyUsage.where(account: account).capacity_holding.count).to eq(2)
  end

  it 'does not deadlock concurrent payment confirmation and partial closure' do
    usage, = terminal_partial_reply
    operator = create(:platform_app, finance_operations_enabled: true)
    purchase_preview = AiLeadEmployee::Subscriptions::PurchasePreview.new(
      account: account, plan: subscription.ai_service_plan, purpose: :top_up
    ).perform
    request = AiLeadEmployee::Subscriptions::RequestService.new(
      account: account, requested_by: create(:user, account: account, role: :administrator),
      plan: subscription.ai_service_plan, purpose: :top_up,
      preview_signature: AiLeadEmployee::Subscriptions::PurchasePreview.signature_for(
        account: account, preview: purchase_preview
      )
    ).perform
    gate = Queue.new
    workers = [
      lambda {
        described_class.reconcile!(usage: usage, outcome: 'confirmed_partial_failure', platform_app: operator,
                                   reason: 'terminal_provider_lookup')
      },
      lambda {
        AiLeadEmployee::Subscriptions::PaymentConfirmationService.new(
          account: account, request: request, platform_app: operator,
          attributes: { payment_reference: 'CONCURRENT-CLOSE', amount: request.quoted_amount,
                        currency: request.currency, confirmed_at: Time.current.iso8601 }
        ).perform
      }
    ].map do |action|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          action.call
        rescue StandardError => e
          e
        end
      end
    end
    2.times { gate << true }

    expect(workers).to all(satisfy { |thread| thread.join(10) == thread })
    outcomes = workers.map(&:value)
    errors = outcomes.grep(StandardError)
    expect(errors).to all(be_a(AiLeadEmployee::Subscriptions::PaymentConfirmationService::InvalidConfirmation).and(
                            have_attributes(message: 'Subscription changed after this request; create a new payment request')
                          ))
    expect(usage.reload).to be_partial_failure_closed
    expect(request.reload.status).to be_in(%w[pending confirmed])
    expect(AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: account).count).to eq(request.confirmed? ? 1 : 0)
  end

  it 'rechecks current finance authority before closing a partial failure' do
    usage = described_class.reserve!(intent: intent_for)
    usage.update!(status: :partially_delivered, reconciliation_reason: 'partial_delivery_requires_reconciliation')
    app = create(:platform_app, finance_operations_enabled: true)
    app.update!(finance_operations_enabled: false)

    expect do
      described_class.reconcile!(usage: usage, outcome: 'confirmed_partial_failure', platform_app: app,
                                 reason: 'not_authorized')
    end.to raise_error(ArgumentError, 'Current finance authority is required')

    expect(usage.reload).to be_partially_delivered
  end

  it 'settles at the canonical receipt time rather than the earlier HTTP acceptance time' do
    intent = intent_for
    usage = described_class.reserve!(intent: intent, at: Time.zone.parse('2026-09-12 08:00:00 UTC'))
    message = create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                               message_type: :outgoing,
                               additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    delivery = delivery_for(message, usage)
    described_class.register_deliveries!(usage: usage, messages: [message])
    delivery.update!(state: :accepted, accepted_at: Time.zone.parse('2026-09-12 08:00:02 UTC'),
                     provider_message_id: 'wamid.delayed.receipt')

    Whatsapp::MessageStatusProjector.new(
      message: message.reload,
      status: { status: 'sent', timestamp: Time.zone.parse('2026-09-12 08:05:00 UTC').to_i.to_s }
    ).perform

    expect(usage.reload).to have_attributes(
      status: 'settled', settled_at: Time.zone.parse('2026-09-12 08:05:00 UTC')
    )
  end

  it 'does not bill HTTP acceptance and releases a later provider failed receipt' do
    intent = intent_for
    usage = described_class.reserve!(intent: intent)
    message = create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                               message_type: :outgoing,
                               additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    delivery = delivery_for(message, usage)
    described_class.register_deliveries!(usage: usage, messages: [message])
    delivery.update!(state: :accepted, accepted_at: Time.current, provider_message_id: 'wamid.failed.later')

    expect(usage.reload).to be_reserved
    Whatsapp::MessageStatusProjector.new(
      message: message.reload, status: { status: 'failed', timestamp: Time.current.to_i.to_s }
    ).perform

    expect(usage.reload).to be_released
  end

  it 'reuses the same released unit when an authorised operator retries a confirmed failure' do
    admin = create(:user, account: account, role: :administrator)
    intent = intent_for
    usage = described_class.reserve!(intent: intent, at: Time.zone.parse('2026-09-12 08:00:00 UTC'))
    message = create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                               message_type: :outgoing,
                               additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    delivery = delivery_for(message, usage)
    described_class.register_deliveries!(usage: usage, messages: [message])
    delivery.update!(state: :failed, failure_code: 'provider_rejected')

    expect(usage.reload).to be_released
    expect(subscription.alerts.open.allowance_exhausted).to be_empty
    expect(delivery.retry_for?(admin)).to be(true)
    expect(usage.reload).to be_reserved
    expect(subscription.alerts.open.allowance_exhausted.count).to eq(1)
    expect(AiLeadEmployee::AiReplyUsage.where(ai_orchestration_intent: intent).count).to eq(1)
  end

  it 'isolates allowance by Business Account' do
    other_account = create(:account)
    create(:ai_subscription, account: other_account, included_ai_replies: 1)

    described_class.reserve!(intent: intent_for(other_account), at: Time.zone.parse('2026-09-12 08:00:00 UTC'))

    expect(described_class.summary(account: account, at: Time.zone.parse('2026-09-12 08:00:00 UTC'))[:remaining_ai_replies]).to eq(1)
  end

  it 'rejects a delivery association to another Business Account allowance' do
    other_account = create(:account)
    create(:ai_subscription, account: other_account)
    other_usage = described_class.reserve!(intent: intent_for(other_account))
    message = create(:message, account: account)
    delivery = Whatsapp::OutboundDelivery.new(
      account: account, conversation: message.conversation, message: message, ai_reply_usage: other_usage,
      observed_control_version: message.conversation.control_version
    )

    expect(delivery).not_to be_valid
    expect(delivery.errors[:ai_reply_usage]).to include('must belong to the same Business Account')
    expect(AiLeadEmployee::AiReplyUsage.for_delivery(delivery)).to be_nil
  end
end
