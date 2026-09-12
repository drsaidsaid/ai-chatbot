# frozen_string_literal: true

class Platform::Api::V1::AiServicePlansController < PlatformController
  skip_before_action :set_resource, only: [:update]
  skip_before_action :validate_platform_app_permissible, only: [:update]
  before_action :plan, only: [:update, :publish]
  before_action :validate_finance_operator

  def index
    render json: AiLeadEmployee::AiServicePlan.order(:code, :version).map { |record| payload(record) }
  end

  def create
    record = AiLeadEmployee::AiServicePlan.create!(plan_params)
    render json: payload(record), status: :created
  end

  def update
    @plan.update!(plan_params)
    render json: payload(@plan)
  end

  def publish
    @plan = @plan.publish!
    render json: payload(@plan)
  end

  private

  def plan
    @plan = AiLeadEmployee::AiServicePlan.find(params[:id])
  end

  def plan_params
    params.permit(
      :code, :name, :version, :currency, :monthly_price, :included_ai_replies,
      :top_up_price, :top_up_ai_replies, :payment_instructions
    )
  end

  def payload(record)
    record.as_json(
      only: %i[id code name version status currency monthly_price included_ai_replies top_up_price
               top_up_ai_replies payment_instructions published_at]
    )
  end
end
