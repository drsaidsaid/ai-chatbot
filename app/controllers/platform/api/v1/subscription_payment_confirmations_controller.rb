# frozen_string_literal: true

class Platform::Api::V1::SubscriptionPaymentConfirmationsController < PlatformController
  before_action :set_resource
  before_action :validate_platform_app_permissible
  before_action :validate_finance_operator

  def create
    request_record = AiLeadEmployee::AiSubscriptionRequest.find_by!(
      id: params[:subscription_request_id], account_id: @resource.id
    )
    confirmation = AiLeadEmployee::Subscriptions::PaymentConfirmationService.new(
      account: @resource,
      request: request_record,
      platform_app: @platform_app,
      attributes: params.permit(:payment_reference, :amount, :currency, :confirmed_at, :granted_ai_replies)
    ).perform
    render json: confirmation.as_json(only: %i[id purpose payment_reference amount currency granted_ai_replies confirmed_at])
  rescue AiLeadEmployee::Subscriptions::PaymentConfirmationService::InvalidConfirmation => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_resource
    @resource = Account.find(params[:account_id])
  end
end
