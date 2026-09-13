# frozen_string_literal: true

class Api::V1::Accounts::AiSubscriptionRequestsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def create
    plan = AiLeadEmployee::AiServicePlan.find_by(id: params[:ai_service_plan_id])
    request_record = AiLeadEmployee::Subscriptions::RequestService.new(
      account: current_account,
      requested_by: current_user,
      plan: plan,
      purpose: params[:purpose],
      preview_signature: params[:preview_signature]
    ).perform
    render json: payload(request_record), status: :created
  rescue AiLeadEmployee::Subscriptions::RequestService::InvalidRequest => e
    Rails.logger.info("AI subscription request rejected: #{e.class}")
    render json: { error: 'subscription_request_unavailable' }, status: :unprocessable_entity
  end

  private

  def payload(request_record)
    {
      id: request_record.id,
      purpose: request_record.purpose,
      status: request_record.status,
      amount: request_record.quoted_amount && format('%.2f', request_record.quoted_amount),
      currency: request_record.currency,
      requested_ai_replies: request_record.requested_ai_replies,
      payment_instructions: request_record.payment_instructions
    }
  end
end
