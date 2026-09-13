# frozen_string_literal: true

class Platform::Api::V1::AccountCostAllocationsController < PlatformController
  before_action :set_resource
  before_action :validate_platform_app_permissible
  before_action :validate_finance_operator

  def index
    render json: { items: allocations.order(period_started_on: :desc, category: :asc).map { |item| allocation_payload(item) } }
  end

  def create
    allocation = allocations.create!(allocation_params.merge(recorded_by_platform_app: @platform_app))
    render json: allocation_payload(allocation), status: :created
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.cause.is_a?(PG::ExclusionViolation)

    render json: { error: 'Cost allocation periods must not overlap' }, status: :unprocessable_entity
  end

  private

  def set_resource
    @resource = Account.find(params[:account_id])
  end

  def allocations
    AiLeadEmployee::AccountCostAllocation.where(account_id: @resource.id)
  end

  def allocation_params
    params.permit(:category, :amount, :currency, :period_started_on, :period_ended_on).tap do |attributes|
      attributes[:currency] = attributes[:currency].to_s.upcase
    end
  end

  def allocation_payload(allocation)
    allocation.as_json(only: %i[id category amount currency period_started_on period_ended_on created_at])
  end
end
