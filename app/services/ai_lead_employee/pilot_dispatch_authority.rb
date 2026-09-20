# frozen_string_literal: true

class AiLeadEmployee::PilotDispatchAuthority
  def initialize(message:, conversation:, authorization:, usage:)
    @message = message
    @conversation = conversation
    @authorization = authorization
    @usage = usage
  end

  def failure_code # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return 'pilot_authorization_missing' unless authorization && usage
    return 'pilot_authorization_stopped' unless authorization.active?
    return 'pilot_authorization_expired' unless authorization.starts_at <= Time.current && authorization.expires_at > Time.current
    return 'pilot_scope_changed' unless exact_scope?
    return 'pilot_provider_changed' unless provider_current?
    return 'pilot_usage_invalid' unless usage_current?

    nil
  end

  private

  attr_reader :message, :conversation, :authorization, :usage

  def attributes
    message.additional_attributes.fetch('ai_lead_employee', {})
  end

  def exact_scope? # rubocop:disable Metrics/AbcSize
    authorization.account_id == message.account_id && authorization.inbox_id == message.inbox_id &&
      authorization.contact_id == conversation.contact_id && authorization.conversation_id == conversation.id &&
      authorization.recipient == conversation.contact_inbox&.source_id.to_s &&
      authorization.control_version == conversation.control_version
  end

  def provider_current?
    connection = authorization.ai_provider_connection
    connection.account_id == message.account_id &&
      connection.configuration_version == authorization.provider_configuration_version
  end

  def usage_current?
    usage.pilot_authorization_id == authorization.id && usage.ai_orchestration_intent_id.to_s == attributes['orchestration_intent_id'].to_s &&
      usage.ai_provider_connection_id == authorization.ai_provider_connection_id &&
      usage.configuration_version == authorization.provider_configuration_version &&
      usage.completed? && usage.cost_available?
  end
end
