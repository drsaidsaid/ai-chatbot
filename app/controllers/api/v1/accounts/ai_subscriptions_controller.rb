# frozen_string_literal: true

class Api::V1::Accounts::AiSubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: {
      subscription: subscription_payload,
      available_plans: available_plans.map { |plan| plan_payload(plan) },
      pending_requests: pending_requests.map { |request| request_payload(request) },
      alerts: open_alerts.map { |alert| alert.as_json(only: %i[id kind status period_started_at created_at]) },
      separate_charges: {
        meta_messaging: 'Billed directly by Meta',
        advertising_spend: 'Billed separately by the advertising platform'
      }
    }
  end

  def preview
    plan = AiLeadEmployee::AiServicePlan.find_by(id: params[:ai_service_plan_id])
    result = AiLeadEmployee::Subscriptions::PurchasePreview.new(
      account: current_account, plan: plan, purpose: params[:purpose]
    ).perform
    render json: preview_payload(result)
  rescue AiLeadEmployee::Subscriptions::PurchasePreview::InvalidPreview => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def subscription_payload
    summary = AiLeadEmployee::ReplyAllowance.summary(account: current_account)
    subscription = AiLeadEmployee::AiSubscription.find_by(account_id: current_account.id)
    return summary unless subscription

    details = { renewal_date_label: renewal_label(subscription) }
    if summary[:status] == 'renewal_due'
      consumed_top_ups = subscription.reply_usages.capacity_holding.top_up.count
      details[:preserved_top_up_ai_replies] = [subscription.top_up_ai_replies - consumed_top_ups, 0].max
    end
    summary.merge(details)
  end

  def pending_requests
    AiLeadEmployee::AiSubscriptionRequest.where(account_id: current_account.id).pending.order(created_at: :desc)
  end

  def plan_payload(plan)
    {
      id: plan.id, code: plan.code, name: plan.name, currency: plan.currency,
      monthly_price: money(plan.monthly_price), included_ai_replies: plan.included_ai_replies,
      top_up_price: money(plan.top_up_price), top_up_ai_replies: plan.top_up_ai_replies,
      payment_instructions: plan.payment_instructions
    }
  end

  def available_plans
    current_plan_id = AiLeadEmployee::AiSubscription.find_by(account_id: current_account.id)&.ai_service_plan_id
    AiLeadEmployee::AiServicePlan.where(status: 'published').or(AiLeadEmployee::AiServicePlan.where(id: current_plan_id))
                                 .order(:monthly_price, :id)
  end

  def request_payload(request)
    request.as_json(only: %i[id purpose status currency requested_ai_replies payment_instructions created_at])
           .merge('quoted_amount' => money(request.quoted_amount))
  end

  def open_alerts
    AiLeadEmployee::AiSubscriptionAlert.where(account_id: current_account.id, status: 'open').order(created_at: :desc)
  end

  def preview_payload(result)
    result.merge(
      amount_due: money(result[:amount_due]),
      current_monthly_price: money(result[:current_monthly_price]),
      target_monthly_price: money(result[:target_monthly_price]),
      unit_price_comparison: comparison_payload(result[:unit_price_comparison]),
      preview_signature: AiLeadEmployee::Subscriptions::PurchasePreview.signature_for(
        account: current_account, preview: result
      )
    )
  end

  def comparison_payload(comparison)
    return unless comparison

    comparison.merge(
      top_up_unit_price: money(comparison[:top_up_unit_price]),
      included_unit_price: money(comparison[:included_unit_price])
    )
  end

  def money(amount)
    amount && format('%.2f', amount)
  end

  def renewal_label(subscription)
    subscription.renews_at.in_time_zone(subscription.reporting_timezone).strftime('%-d %b %Y, %H:%M %Z')
  end
end
