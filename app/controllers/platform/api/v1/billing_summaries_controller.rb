# frozen_string_literal: true

class Platform::Api::V1::BillingSummariesController < PlatformController
  before_action :validate_finance_operator

  def show
    period_start, period_end, period_range = reporting_period
    usages = AiLeadEmployee::AiProviderUsage.where(account: @resource, started_at: period_range)
    unknown_cost_records = usages.where('cost_available = ? OR cost_usd IS NULL', false).count
    known_provider_cost_usd = usages.where(cost_available: true).where.not(cost_usd: nil).sum(:cost_usd)
    revenue = revenue_for(period_range)
    allocations = AiLeadEmployee::AccountCostAllocation.where(account: @resource).overlapping(period_start, period_end)
    allocation_summary = allocation_summary(allocations, period_start, period_end)
    margin = estimated_margin(revenue, known_provider_cost_usd, unknown_cost_records, allocation_summary)

    render json: billing_payload(revenue, known_provider_cost_usd, unknown_cost_records, allocation_summary, margin)
  end

  private

  def billing_payload(revenue, known_provider_cost_usd, unknown_cost_records, allocation_summary, margin)
    {
      account_id: @resource.id,
      customer_revenue_by_currency: revenue.transform_values { |amount| amount.to_s('F') },
      provider_costs: {
        currency: 'USD',
        known_amount: known_provider_cost_usd.to_s('F'),
        unknown_records: unknown_cost_records,
        complete: unknown_cost_records.zero?
      },
      operating_cost_allocations: allocation_summary,
      estimated_contribution_margin: margin,
      meta_messaging: { billing_owner: 'Meta', included_in_ai_credits: false },
      advertising_spend: { billing_owner: 'Advertising platform', included_in_ai_credits: false }
    }
  end

  def set_resource
    @resource = Account.find(params[:account_id])
  end

  def reporting_period
    subscription = AiLeadEmployee::AiSubscription.find_by(account_id: @resource.id)
    unless subscription
      range = Time.current.all_month
      return [range.begin.to_date, range.end.to_date, range]
    end

    subscription.with_lock { subscription.roll_period_forward!(at: Time.current) }
    zone = ActiveSupport::TimeZone[subscription.reporting_timezone] || ActiveSupport::TimeZone['UTC']
    start_at = subscription.period_started_at.in_time_zone(zone)
    end_at = subscription.renews_at.in_time_zone(zone)
    [start_at.to_date, (end_at - 1.second).to_date, start_at...end_at]
  end

  def revenue_for(period_range)
    AiLeadEmployee::SubscriptionPaymentConfirmation
      .where(account: @resource, confirmed_at: period_range)
      .group(:currency).sum(:amount)
  end

  def allocation_summary(allocations, period_start, period_end)
    exact_allocations = allocations.where(period_started_on: period_start, period_ended_on: period_end)
    partial_records = allocations.exists?(['period_started_on != ? OR period_ended_on != ?', period_start, period_end])
    duplicate_categories = exact_allocations.group(:category).count.values.any? { |count| count != 1 }
    categories = exact_allocations.distinct.pluck(:category)
    {
      period_started_on: period_start,
      period_ended_on: period_end,
      totals_by_currency: exact_allocations.group(:currency).sum(:amount).transform_values { |amount| amount.to_s('F') },
      categories: categories.sort,
      complete: !partial_records && !duplicate_categories &&
        (AiLeadEmployee::AccountCostAllocation::CATEGORIES - categories).empty?
    }
  end

  def estimated_margin(revenue, known_provider_cost_usd, unknown_cost_records, allocations)
    return { amount: nil, currency: nil, complete: false, reason: 'provider_cost_unknown' } if unknown_cost_records.positive?
    return { amount: nil, currency: nil, complete: false, reason: 'operating_costs_unallocated' } unless allocations[:complete]
    return { amount: nil, currency: nil, complete: false, reason: 'currency_not_comparable' } unless revenue.keys == ['USD']

    allocation_totals = allocations[:totals_by_currency]
    return { amount: nil, currency: nil, complete: false, reason: 'currency_not_comparable' } unless allocation_totals.keys == ['USD']

    {
      amount: (revenue.fetch('USD') - known_provider_cost_usd - BigDecimal(allocation_totals.fetch('USD'))).to_s('F'),
      currency: 'USD',
      complete: true,
      reason: nil
    }
  end
end
