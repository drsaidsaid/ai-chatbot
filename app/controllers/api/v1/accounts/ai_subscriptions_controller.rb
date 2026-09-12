# frozen_string_literal: true

class Api::V1::Accounts::AiSubscriptionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: {
      subscription: AiLeadEmployee::ReplyAllowance.summary(account: current_account),
      available_plans: available_plans.map { |plan| plan_payload(plan) },
      pending_requests: pending_requests.map { |request| request_payload(request) },
      alerts: open_alerts.map { |alert| alert.as_json(only: %i[id kind status period_started_at created_at]) },
      separate_charges: {
        meta_messaging: 'Billed directly by Meta',
        advertising_spend: 'Billed separately by the advertising platform'
      }
    }
  end

  private

  def pending_requests
    AiLeadEmployee::AiSubscriptionRequest.where(account_id: current_account.id).pending.order(created_at: :desc)
  end

  def plan_payload(plan)
    plan.as_json(
      only: %i[id code name currency monthly_price included_ai_replies top_up_price top_up_ai_replies
               payment_instructions]
    )
  end

  def available_plans
    current_plan_id = AiLeadEmployee::AiSubscription.find_by(account_id: current_account.id)&.ai_service_plan_id
    AiLeadEmployee::AiServicePlan.where(status: 'published').or(AiLeadEmployee::AiServicePlan.where(id: current_plan_id))
                                 .order(:monthly_price, :id)
  end

  def request_payload(request)
    request.as_json(only: %i[id purpose status quoted_amount currency requested_ai_replies payment_instructions created_at])
  end

  def open_alerts
    AiLeadEmployee::AiSubscriptionAlert.where(account_id: current_account.id, status: 'open').order(created_at: :desc)
  end
end
