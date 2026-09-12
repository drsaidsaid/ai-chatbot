# frozen_string_literal: true

class Platform::Api::V1::AiReplyUsagesController < PlatformController
  before_action :set_resource, only: %i[index update]
  before_action :validate_platform_app_permissible, only: %i[index update]
  before_action :validate_finance_operator

  def index
    limit = page_limit
    page = reconciliation_scope.limit(limit + 1).to_a
    has_more = page.length > limit
    page = page.first(limit)
    render json: { items: page.map { |usage| usage_payload(usage) }, next_after_id: has_more ? page.last.id : nil }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

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

  def reconciliation_scope
    status = params[:status].presence || 'reserved'
    raise ArgumentError, 'Status is invalid' unless status.in?(AiLeadEmployee::AiReplyUsage.statuses.keys)

    AiLeadEmployee::AiReplyUsage.where(account_id: @resource.id, status: status)
                                .where('id > ?', params[:after_id].to_i)
                                .includes(:whatsapp_outbound_deliveries)
                                .order(id: :asc)
  end

  def page_limit
    params.fetch(:limit, 50).to_i.clamp(1, 100)
  end

  def usage_payload(usage)
    usage.as_json(
      only: %i[id status allowance_source expected_delivery_parts deliveries_registered_at period_started_at period_ends_at
               reserved_at reconciliation_reason],
      methods: []
    ).merge(deliveries: usage.whatsapp_outbound_deliveries.map do |delivery|
      delivery.as_json(only: %i[id message_id state provider_message_id failure_code accepted_at])
    end)
  end
end
