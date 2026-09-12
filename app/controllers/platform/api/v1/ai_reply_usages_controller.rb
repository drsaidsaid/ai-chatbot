# frozen_string_literal: true

class Platform::Api::V1::AiReplyUsagesController < PlatformController
  before_action :validate_finance_operator

  def update
    usage = AiLeadEmployee::AiReplyUsage.find_by!(id: params[:id], account_id: @resource.id)
    usage = AiLeadEmployee::ReplyAllowance.reconcile!(
      usage: usage,
      outcome: params[:outcome],
      reason: params[:reason].presence || 'manual_conservative_reconciliation',
      platform_app: @platform_app
    )
    render json: usage.as_json(only: %i[id status allowance_source settled_at released_at reconciliation_reason])
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_resource
    @resource = Account.find(params[:account_id])
  end
end
