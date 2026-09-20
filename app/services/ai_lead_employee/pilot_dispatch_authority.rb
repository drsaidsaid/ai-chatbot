# frozen_string_literal: true

class AiLeadEmployee::PilotDispatchAuthority
  PROVIDER_FREE_STATUSES = %w[conversation_reply review_acknowledgment].freeze

  def initialize(message:, conversation:, authorization:, usage:, intent:)
    @message = message
    @conversation = conversation
    @authorization = authorization
    @usage = usage
    @intent = intent
  end

  def failure_code # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return 'pilot_authorization_missing' unless authorization
    return 'pilot_authorization_stopped' unless authorization.active? || deliverable_known_usage_after_cost_uncertainty?
    return 'pilot_authorization_expired' unless authorization.starts_at <= Time.current && authorization.expires_at > Time.current
    return 'pilot_scope_changed' unless exact_scope?
    return 'pilot_provider_changed' unless provider_current?
    return 'pilot_intent_invalid' unless intent_current?
    return 'pilot_intent_invalid' unless outbound_status_current?
    return provider_free_failure if provider_free?
    return 'pilot_usage_invalid' unless usage
    return 'pilot_usage_invalid' unless usage_current?

    nil
  end

  private

  attr_reader :message, :conversation, :authorization, :usage, :intent

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

  def intent_current? # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return false unless intent

    trigger = intent&.triggering_message
    intent&.id.to_s == attributes['orchestration_intent_id'].to_s && intent.pilot_authorization_id == authorization.id &&
      intent.account_id == authorization.account_id && intent.conversation_id == authorization.conversation_id &&
      intent.observed_control_version == authorization.control_version && intent.outbound_message_id == message.id &&
      trigger&.account_id == authorization.account_id && trigger&.inbox_id == authorization.inbox_id &&
      trigger&.conversation_id == authorization.conversation_id && trigger&.sender_id == authorization.contact_id
  end

  def provider_free?
    provider_free_status.present?
  end

  def provider_free_status
    return 'conversation_reply' if intent.decision['status'] == 'conversation_reply'

    acknowledgment = intent.decision['acknowledgment']
    return unless intent.review_request_id.present? && acknowledgment&.fetch('outbound_message_id', nil).to_s == message.id.to_s

    'review_acknowledgment'
  end

  def outbound_status_current?
    persisted_status = persisted_outbound_status
    persisted_status.present? && attributes['outbound_intent_status'].to_s == persisted_status
  end

  def persisted_outbound_status
    provider_free_status || intent.decision['status']
  end

  def provider_free_failure
    return 'pilot_usage_invalid' if usage || attributes['provider_usage_id'].present? ||
                                    attributes['provider_configuration_version'].present? ||
                                    attributes['provider_usage_period_on'].present? ||
                                    attributes['ai_reply_usage_id'].present?

    nil
  end

  def deliverable_known_usage_after_cost_uncertainty? # rubocop:disable Metrics/CyclomaticComplexity
    authorization.paused? && authorization.pause_reason.in?(%w[provider_cost_unknown provider_cost_unavailable]) &&
      usage&.completed? && usage.cost_available? && usage.completed_at && authorization.paused_at && usage.completed_at < authorization.paused_at
  end
end
