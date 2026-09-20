# frozen_string_literal: true

class AiLeadEmployee::PilotAuthorizationStopper
  def initialize(authorization:, platform_app:, status:, reason:)
    @authorization = authorization
    @platform_app = platform_app
    @status = status
    @reason = reason
  end

  def perform # rubocop:disable Metrics/AbcSize
    raise ActiveRecord::RecordInvalid, authorization unless %w[paused revoked].include?(status)

    record = ActiveRecord::Base.transaction do
      actor = PlatformApp.lock.find(platform_app.id)
      permissible = PlatformAppPermissible.lock.find_by(platform_app: actor, permissible: authorization.account)
      record = AiLeadEmployee::PilotAuthorization.lock.find(authorization.id)
      raise ActiveRecord::RecordInvalid, record unless actor.pilot_operator? && permissible && record.account_id == authorization.account_id

      record.update!(status: status, paused_at: Time.current, pause_reason: reason.presence || "operator_#{status}")
      AiLeadEmployee::PilotAuthorizationEvent.create!(pilot_authorization: record, platform_app: actor, action: status, reason: record.pause_reason)
      record
    end
    AiLeadEmployee::AutomationCancellation.call(conversation: record.conversation, reason: "pilot_#{status}")
    record
  end

  private

  attr_reader :authorization, :platform_app, :status, :reason
end
