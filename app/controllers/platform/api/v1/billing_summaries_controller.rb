# frozen_string_literal: true

class Platform::Api::V1::BillingSummariesController < PlatformController
  before_action :validate_finance_operator

  def show
    usages = AiLeadEmployee::AiProviderUsage.where(account: @resource)
    unknown_cost_records = usages.where('cost_available = ? OR cost_usd IS NULL', false).count
    known_provider_cost_usd = usages.where(cost_available: true).where.not(cost_usd: nil).sum(:cost_usd)
    revenue = AiLeadEmployee::SubscriptionPaymentConfirmation.where(account: @resource).group(:currency).sum(:amount)
    margin = estimated_margin(revenue, known_provider_cost_usd, unknown_cost_records)

    render json: {
      account_id: @resource.id,
      customer_revenue_by_currency: revenue.transform_values { |amount| amount.to_s('F') },
      provider_costs: {
        currency: 'USD',
        known_amount: known_provider_cost_usd.to_s('F'),
        unknown_records: unknown_cost_records,
        complete: unknown_cost_records.zero?
      },
      estimated_contribution_margin: margin,
      meta_messaging: { billing_owner: 'Meta', included_in_ai_credits: false },
      advertising_spend: { billing_owner: 'Advertising platform', included_in_ai_credits: false },
      unallocated_costs: %w[hosting payment_processing support]
    }
  end

  private

  def set_resource
    @resource = Account.find(params[:account_id])
  end

  def estimated_margin(revenue, known_provider_cost_usd, unknown_cost_records)
    return { amount: nil, currency: nil, complete: false, reason: 'provider_cost_unknown' } if unknown_cost_records.positive?
    return { amount: nil, currency: nil, complete: false, reason: 'currency_not_comparable' } unless revenue.keys == ['USD']

    {
      amount: (revenue.fetch('USD') - known_provider_cost_usd).to_s('F'),
      currency: 'USD',
      complete: false,
      reason: 'operating_costs_unallocated'
    }
  end
end
