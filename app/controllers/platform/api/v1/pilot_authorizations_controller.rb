# frozen_string_literal: true

class Platform::Api::V1::PilotAuthorizationsController < PlatformController
  before_action :set_resource
  before_action :validate_platform_app_permissible
  before_action :validate_pilot_operator

  def create
    conversation = @resource.conversations.find(params.require(:conversation_id))
    authorization = AiLeadEmployee::PilotAuthorizationActivator.new(
      account: @resource, conversation: conversation,
      max_attempts: params.require(:max_attempts), max_spend_usd: params.require(:max_spend_usd),
      expires_at: params.require(:expires_at), platform_app: @platform_app
    ).perform
    render json: payload(authorization), status: :created
  end

  def update
    authorization = AiLeadEmployee::PilotAuthorization.where(account_id: @resource.id).find(params[:id])
    status = params.require(:status)
    raise ActionController::BadRequest, 'status must pause or revoke the authorization' unless status.in?(%w[paused revoked])

    authorization.update!(status: status, paused_at: Time.current, pause_reason: params[:reason].presence || "operator_#{status}")
    AiLeadEmployee::AutomationCancellation.call(conversation: authorization.conversation, reason: "pilot_#{status}")
    render json: payload(authorization)
  end

  private

  def set_resource
    @resource = Account.find(params[:account_id])
  end

  def validate_pilot_operator
    return if @platform_app&.pilot_operator?

    render json: { error: 'Pilot operations permission required' }, status: :unauthorized
  end

  def payload(record)
    record.as_json(only: %i[id account_id inbox_id contact_id conversation_id ai_provider_connection_id recipient
                            control_version provider_configuration_version status max_attempts max_spend_usd
                            provider_limit_usd provider_limit_verified_at starts_at expires_at paused_at pause_reason])
  end
end
