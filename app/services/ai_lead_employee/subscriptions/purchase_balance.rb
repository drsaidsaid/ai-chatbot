# frozen_string_literal: true

class AiLeadEmployee::Subscriptions::PurchaseBalance
  def initialize(subscription:, plan:, purpose:)
    @subscription = subscription
    @plan = plan
    @purpose = purpose
  end

  def to_h
    return empty_balances unless subscription

    usages = subscription.reply_usages.capacity_holding
    period_usages = usages.where(period_started_at: subscription.period_started_at)
    counts = usage_counts(usages, period_usages)
    current = current_balances(counts)

    {
      used_ai_replies: period_usages.settled.count,
      awaiting_delivery_ai_replies: period_usages.where(status: %w[reserved partially_delivered]).count,
      current_included_ai_replies_remaining: current.fetch(:included),
      current_top_up_ai_replies_remaining: current.fetch(:top_up),
      current_remaining_ai_replies: current.values.sum
    }.merge(resulting_balances(counts, current))
  end

  private

  attr_reader :subscription, :plan, :purpose

  def usage_counts(usages, period_usages)
    {
      included_holding: period_usages.included.count,
      period_top_up_holding: period_usages.top_up.count,
      all_top_up_holding: usages.top_up.count
    }
  end

  def current_balances(counts)
    {
      included: [subscription.included_ai_replies - counts.fetch(:included_holding), 0].max,
      top_up: [subscription.top_up_ai_replies - counts.fetch(:all_top_up_holding), 0].max
    }
  end

  def resulting_balances(counts, current)
    included, top_up = if purpose == 'upgrade'
                         upgrade_balances(counts)
                       elsif purpose == 'top_up'
                         [current.fetch(:included), current.fetch(:top_up) + plan.top_up_ai_replies]
                       else
                         current.values_at(:included, :top_up)
                       end

    {
      resulting_included_ai_replies_remaining: included,
      resulting_top_up_ai_replies_remaining: top_up,
      resulting_ai_replies_remaining: included + top_up
    }
  end

  def upgrade_balances(counts)
    newly_available = [plan.included_ai_replies - counts.fetch(:included_holding), 0].max
    rebalanced_top_ups = [counts.fetch(:period_top_up_holding), newly_available].min
    included = [plan.included_ai_replies - counts.fetch(:included_holding) - rebalanced_top_ups, 0].max
    top_up = [subscription.top_up_ai_replies - counts.fetch(:all_top_up_holding) + rebalanced_top_ups, 0].max
    [included, top_up]
  end

  def empty_balances
    {
      used_ai_replies: 0,
      awaiting_delivery_ai_replies: 0,
      current_included_ai_replies_remaining: 0,
      current_top_up_ai_replies_remaining: 0,
      current_remaining_ai_replies: 0,
      resulting_included_ai_replies_remaining: plan.included_ai_replies,
      resulting_top_up_ai_replies_remaining: 0,
      resulting_ai_replies_remaining: plan.included_ai_replies
    }
  end
end
