# frozen_string_literal: true

class Api::V1::Accounts::OperationalDashboardsController < Api::V1::Accounts::BaseController
  def show
    render json: AiLeadEmployee::OperationalDashboardService.new(
      account: current_account,
      user: Current.user,
      filters: dashboard_params
    ).perform
  end

  private

  def dashboard_params
    params.permit(
      :quality,
      :follow_up_state,
      :follow_up_status,
      :assignee_id,
      :source_id,
      :unanswered,
      :review_status,
      :booking_status,
      :knowledge_approval,
      :control_state
    )
  end
end
