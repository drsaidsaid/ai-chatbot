# frozen_string_literal: true

class AiLeadEmployee::ReplyAllowance
  Exhausted = Class.new(StandardError)

  class << self
    def reserve!(intent:, at: Time.current)
      existing = AiLeadEmployee::AiReplyUsage.find_by(ai_orchestration_intent: intent)
      return existing if existing

      result = with_active_subscription(intent.account) do |subscription|
        reserve_under_lock!(subscription: subscription, intent: intent, at: at)
      end
      raise Exhausted, result.to_s if result.in?(%i[customer_allowance_exhausted subscription_renewal_due])

      result
    end

    def summary(account:, at: Time.current)
      subscription = AiLeadEmployee::AiSubscription.find_by(account_id: account.id)
      return unavailable_summary unless subscription&.active?

      subscription.with_lock do
        current = subscription.roll_period_forward!(at: at)
        current ? summary_for(subscription) : renewal_due_summary(subscription, at)
      end
    end

    def reconcile_delivery!(delivery)
      AiLeadEmployee::ReplyUsageReconciler.reconcile_delivery!(delivery)
    end

    def register_deliveries!(usage:, messages:, at: Time.current)
      AiLeadEmployee::ReplyUsageReconciler.register_deliveries!(usage: usage, messages: messages, at: at)
    end

    def reconcile!(usage:, outcome:, platform_app:, reason:)
      AiLeadEmployee::ReplyUsageReconciler.reconcile!(
        usage: usage, outcome: outcome, platform_app: platform_app, reason: reason
      )
    end

    def release!(usage:, reason:, platform_app: nil)
      usage.ai_subscription.with_lock do
        usage.lock!
        if usage.reserved?
          usage.update!(
            status: :released, released_at: Time.current, reconciliation_reason: reason,
            reconciled_by_platform_app: platform_app
          )
        end
        usage.ai_subscription.resolve_alerts!(kind: :allowance_exhausted) if available_source(usage.ai_subscription)
      end
      usage
    end

    def delivery_failure_code(message:, at: Time.current)
      usage_id = message.additional_attributes.dig('ai_lead_employee', 'ai_reply_usage_id')
      return if usage_id.blank?

      usage = AiLeadEmployee::AiReplyUsage.includes(:ai_subscription).find_by(id: usage_id, account_id: message.account_id)
      return 'customer_allowance_unavailable' unless usage

      terminal_failure = usage.delivery_failure_code
      return terminal_failure if terminal_failure
      return 'subscription_inactive' unless usage.ai_subscription.active?
      return 'customer_allowance_period_expired' if usage.reserved? && at >= usage.period_ends_at
    end

    def rereserve_for_delivery!(delivery, at: Time.current)
      usage = delivery_usage(delivery)
      return true unless usage
      return true if usage.reserved?
      return false unless usage.released?

      usage.ai_subscription.with_lock do
        subscription = usage.ai_subscription
        source = reactivation_source(subscription, at)
        next false unless source

        usage.update!(
          status: :reserved, allowance_source: source, period_started_at: subscription.period_started_at,
          period_ends_at: subscription.renews_at, reserved_at: at, released_at: nil,
          reconciliation_reason: nil, reconciled_by_platform_app: nil
        )
        alert_subscription!(subscription, at, :allowance_exhausted) unless available_source(subscription)
        true
      end
    end

    private

    def delivery_usage(delivery)
      AiLeadEmployee::AiReplyUsage.for_delivery(delivery)
    end

    def with_active_subscription(account)
      subscription = AiLeadEmployee::AiSubscription.find_by(account_id: account.id)
      raise Exhausted, 'AI reply allowance is unavailable' unless subscription&.active?

      subscription.with_lock { yield(subscription) }
    end

    def reactivation_source(subscription, at)
      return unless subscription.active?
      return unless subscription.roll_period_forward!(at: at)

      available_source(subscription)
    end

    def reserve_under_lock!(subscription:, intent:, at:)
      return exhaust!(subscription, at, :subscription_renewal_due) unless subscription.roll_period_forward!(at: at)

      existing = AiLeadEmployee::AiReplyUsage.find_by(ai_orchestration_intent: intent)
      return existing if existing

      source = available_source(subscription)
      return exhaust!(subscription, at, :customer_allowance_exhausted) unless source

      usage = create_reservation(subscription, intent, source, at)
      alert_subscription!(subscription, at, :allowance_exhausted) unless available_source(subscription)
      usage
    end

    def create_reservation(subscription, intent, source, at)
      AiLeadEmployee::AiReplyUsage.create!(
        account: intent.account, ai_subscription: subscription, ai_orchestration_intent: intent,
        allowance_source: source, status: :reserved, period_started_at: subscription.period_started_at,
        period_ends_at: subscription.renews_at, reserved_at: at
      )
    end

    def exhaust!(subscription, at, reason)
      kind = reason == :subscription_renewal_due ? :subscription_renewal_due : :allowance_exhausted
      alert_subscription!(subscription, at, kind)
      reason
    end

    def alert_subscription!(subscription, at, kind)
      subscription.open_alert!(kind: kind, at: at)
    end

    def summary_for(subscription)
      usages = subscription.reply_usages.capacity_holding
      period_usages = usages.where(period_started_at: subscription.period_started_at)
      counts = usage_counts(subscription, usages, period_usages)
      active_summary(subscription, counts)
    end

    def usage_counts(subscription, usages, period_usages)
      included_remaining = [subscription.included_ai_replies - period_usages.included.count, 0].max
      top_up_remaining = [subscription.top_up_ai_replies - usages.top_up.count, 0].max
      {
        settled: period_usages.settled.count,
        reserved: period_usages.reserved.count,
        reconciliation_required: period_usages.partially_delivered.count,
        included_remaining: included_remaining,
        top_up_remaining: top_up_remaining,
        remaining: included_remaining + top_up_remaining
      }
    end

    def active_summary(subscription, counts)
      total_capacity = counts.values_at(:settled, :reserved, :reconciliation_required, :remaining).sum
      unavailable = counts[:settled] + counts[:reconciliation_required]
      {
        status: 'active', plan_id: subscription.ai_service_plan_id, plan_name: subscription.ai_service_plan.name,
        currency: subscription.ai_service_plan.currency, renewal_date: subscription.renews_at,
        included_ai_replies: subscription.included_ai_replies, used_ai_replies: counts[:settled],
        reserved_ai_replies: counts[:reserved], remaining_ai_replies: counts[:remaining],
        reconciliation_required_ai_replies: counts[:reconciliation_required],
        top_up_ai_replies_remaining: counts[:top_up_remaining], usage_percentage: usage_percentage(unavailable, total_capacity),
        automation_allowed: counts[:remaining].positive?,
        automation_paused_reason: counts[:remaining].zero? ? 'customer_allowance_exhausted' : nil,
        action_required_alerted_at: subscription.action_required_alerted_at
      }
    end

    def usage_percentage(consumed, total_capacity)
      total_capacity.zero? ? 100.0 : ((consumed.to_f / total_capacity) * 100).round(1)
    end

    def available_source(subscription)
      active = subscription.reply_usages.capacity_holding
      included_used = active.where(period_started_at: subscription.period_started_at, allowance_source: 'included').count
      return 'included' if included_used < subscription.included_ai_replies

      top_up_used = active.where(allowance_source: 'top_up').count
      return 'top_up' if top_up_used < subscription.top_up_ai_replies
    end

    public :available_source

    def unavailable_summary
      {
        status: 'inactive', included_ai_replies: 0, used_ai_replies: 0, reserved_ai_replies: 0,
        reconciliation_required_ai_replies: 0,
        remaining_ai_replies: 0, top_up_ai_replies_remaining: 0, usage_percentage: 0.0,
        automation_allowed: false, automation_paused_reason: 'subscription_inactive'
      }
    end

    def renewal_due_summary(subscription, at)
      alert_subscription!(subscription, at, :subscription_renewal_due)
      {
        status: 'renewal_due', plan_id: subscription.ai_service_plan_id, plan_name: subscription.ai_service_plan.name,
        currency: subscription.ai_service_plan.currency, renewal_date: subscription.renews_at,
        included_ai_replies: subscription.included_ai_replies, used_ai_replies: 0, reserved_ai_replies: 0,
        reconciliation_required_ai_replies: 0,
        remaining_ai_replies: 0, top_up_ai_replies_remaining: 0, usage_percentage: 100.0,
        automation_allowed: false, automation_paused_reason: 'subscription_renewal_due',
        action_required_alerted_at: subscription.action_required_alerted_at
      }
    end
  end
end
