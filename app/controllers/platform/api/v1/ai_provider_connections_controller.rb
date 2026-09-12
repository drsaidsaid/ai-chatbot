# frozen_string_literal: true

class Platform::Api::V1::AiProviderConnectionsController < PlatformController
  before_action :set_resource
  before_action :validate_platform_app_permissible
  before_action :connection, only: [:show, :destroy, :health_check]

  def show
    render json: connection_payload
  end

  def update
    record = @resource.ai_provider_connection || @resource.build_ai_provider_connection
    configuration_changed = false
    if record.persisted?
      record.with_lock do
        configuration_changed = configuration_changed?(record)
        apply_connection_update!(record, configuration_changed: configuration_changed)
      end
    else
      apply_connection_update!(record, configuration_changed: false)
    end
    stop_pending_automation!(reason: 'provider_configuration_changed') if configuration_changed

    render json: record.redacted_payload
  end

  def destroy
    @connection&.disable!
    stop_pending_automation!(reason: 'provider_disabled')
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

  def set_resource
    @resource = Account.find(params[:account_id])
  end

  def connection
    @connection ||= @resource.ai_provider_connection
  end

  def connection_payload
    return { status: 'disabled', has_credentials: false } if @connection.blank?

    @connection.redacted_payload
  end

  def connection_params
    params.permit(:provider, :model, :reply_token_limit, :daily_request_limit)
  end

  def configuration_changed?(record)
    params[:api_key].present? || connection_params.to_h.any? do |attribute, value|
      record.public_send(attribute).to_s != value.to_s
    end
  end

  def apply_connection_update!(record, configuration_changed:)
    record.assign_attributes(connection_params.merge(status: :active, disabled_at: nil))
    record.api_key = params[:api_key] if params[:api_key].present?
    reset_readiness!(record) if configuration_changed
    record.save!
  end

  def reset_readiness!(record)
    record.configuration_version += 1
    record.assign_attributes(
      last_health_checked_at: nil,
      last_health_status: nil,
      last_health_failure_class: nil,
      last_health_configuration_version: nil,
      last_health_response: {}
    )
  end

  def stop_pending_automation!(reason:)
    AiLeadEmployee::AiProvider::RuntimeControl.stop_pending_automation!(account: @resource, reason: reason)
  end
end
