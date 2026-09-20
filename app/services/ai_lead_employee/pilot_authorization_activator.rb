# frozen_string_literal: true

class AiLeadEmployee::PilotAuthorizationActivator
  def initialize(account:, conversation:, max_attempts:, max_spend_usd:, expires_at:, platform_app:, verifier: nil) # rubocop:disable Metrics/ParameterLists
    @account = account
    @conversation = conversation
    @max_attempts = max_attempts
    @max_spend_usd = BigDecimal(max_spend_usd.to_s)
    @expires_at = Time.zone.parse(expires_at.to_s)
    @platform_app = platform_app
    @verifier = verifier
  end

  def perform # rubocop:disable Metrics/AbcSize
    raise ActiveRecord::RecordInvalid, authorization unless platform_app.pilot_operator?

    verification = (verifier || default_verifier).perform
    raise ActiveRecord::RecordInvalid, authorization if verification.remaining_usd > max_spend_usd
    raise ActiveRecord::RecordInvalid, authorization if verification.key_expires_at && verification.key_expires_at < expires_at

    conversation.with_lock do
      raise ActiveRecord::RecordInvalid, authorization unless exact_scope?

      authorization.assign_attributes(
        provider_limit_usd: verification.remaining_usd,
        provider_limit_verified_at: verification.verified_at,
        provider_limit_evidence: {
          kind: 'openrouter_key_limit', key_fingerprint: verification.key_fingerprint,
          verification_digest: verification.verification_digest, source: 'openrouter_current_key'
        }
      )
      authorization.save!
      authorization
    end
  end

  private

  attr_reader :account, :conversation, :max_attempts, :max_spend_usd, :expires_at, :platform_app, :verifier

  def authorization
    @authorization ||= AiLeadEmployee::PilotAuthorization.new(
      account: account, inbox: conversation.inbox, contact: conversation.contact, conversation: conversation,
      ai_provider_connection: account.ai_provider_connection, authorized_by_platform_app: platform_app,
      recipient: conversation.contact_inbox&.source_id.to_s, control_version: conversation.control_version,
      provider_configuration_version: account.ai_provider_connection&.configuration_version,
      max_attempts: max_attempts, max_spend_usd: max_spend_usd,
      starts_at: Time.current, expires_at: expires_at
    )
  end

  def exact_scope? # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    account.ai_provider_connection&.configured? && conversation.account_id == account.id && conversation.ai_active? &&
      conversation.open? && conversation.assignee_id.nil? && conversation.contact_inbox&.source_id.present? &&
      max_attempts.to_i.positive? && max_spend_usd.positive? && expires_at&.future?
  end

  def default_verifier
    AiLeadEmployee::AiProvider::OpenRouterKeyLimitVerifier.new(connection: account.ai_provider_connection)
  end
end
