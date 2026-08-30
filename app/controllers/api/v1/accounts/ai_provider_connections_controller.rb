# frozen_string_literal: true

class Api::V1::Accounts::AiProviderConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :connection, only: [:show, :destroy, :health_check]

  def show
    render json: connection_payload
  end

  def update
    record = current_account.ai_provider_connection || current_account.build_ai_provider_connection
    record.assign_attributes(connection_params.except(:api_key).merge(status: :active, disabled_at: nil))
    record.api_key = params[:api_key] if params[:api_key].present?
    record.save!

    render json: record.redacted_payload
  end

  def destroy
    @connection&.disable!
    render json: connection_payload
  end

  def health_check
    return render json: { status: 'disabled', has_credentials: false }, status: :unprocessable_entity if @connection.blank?

    result = AiLeadEmployee::AiProvider::HealthCheck.new(connection: @connection).perform
    render json: {
      status: result.status,
      failure_class: result.failure_class,
      checked_at: result.checked_at
    }.compact
  end

  private

  def connection
    @connection ||= current_account.ai_provider_connection
  end

  def connection_payload
    return { status: 'disabled', has_credentials: false } if @connection.blank?

    @connection.redacted_payload
  end

  def connection_params
    params.permit(:provider, :model)
  end
end
