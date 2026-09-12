# frozen_string_literal: true

class Api::V1::Accounts::AiProviderConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :connection

  def show
    render json: connection_payload
  end

  private

  def connection
    @connection ||= current_account.ai_provider_connection
  end

  def connection_payload
    return unavailable_service_payload if @connection.blank?

    @connection.managed_service_payload
  end

  def unavailable_service_payload
    {
      managed_service: true,
      service_status: 'disabled',
      readiness_status: 'disabled',
      requests_used_today: 0,
      requests_remaining_today: 0,
      automation_allowed: false,
      automation_paused_reason: 'provider_disabled'
    }
  end
end
