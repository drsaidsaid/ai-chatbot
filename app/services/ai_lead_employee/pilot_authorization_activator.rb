# frozen_string_literal: true

class AiLeadEmployee::PilotAuthorizationActivator
  # rubocop:disable Metrics/ParameterLists
  def initialize(account:, conversation:, max_attempts:, max_spend_usd:, expires_at:, platform_app:,
                 external_owner_approval_reference:, verifier: nil)
    @account = account
    @conversation = conversation
    @max_attempts = max_attempts
    @max_spend_usd = BigDecimal(max_spend_usd.to_s)
    @expires_at = Time.zone.parse(expires_at.to_s)
    @platform_app = platform_app
    @external_owner_approval_reference = external_owner_approval_reference.to_s.strip
    @verifier = verifier
  end
  # rubocop:enable Metrics/ParameterLists

  def perform # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    raise ActiveRecord::RecordInvalid, authorization unless platform_app.pilot_operator?

    verified_connection = account.ai_provider_connection
    verification = (verifier || default_verifier(verified_connection)).perform
    raise ActiveRecord::RecordInvalid, authorization if verification.remaining_usd > max_spend_usd || external_owner_approval_reference.blank?
    raise ActiveRecord::RecordInvalid, authorization if verification.key_expires_at && verification.key_expires_at < expires_at

    snapshot = [verified_connection&.id, verified_connection&.configuration_version, key_digest(verified_connection)]
    ActiveRecord::Base.transaction do
      actor = PlatformApp.lock.find(platform_app.id)
      permissible = PlatformAppPermissible.lock.find_by(platform_app: actor, permissible: account)
      locked_conversation = Conversation.lock.find(conversation.id)
      current_connection = AiLeadEmployee::AiProviderConnection.lock.find_by(account: account)
      unless actor.pilot_operator? && permissible && exact_scope?(current_connection, locked_conversation) &&
             snapshot == [current_connection.id, current_connection.configuration_version, key_digest(current_connection)]
        raise ActiveRecord::RecordInvalid, authorization
      end

      record = authorization(current_connection, locked_conversation)
      record.assign_attributes(
        provider_limit_usd: verification.remaining_usd,
        provider_limit_verified_at: verification.verified_at,
        provider_limit_evidence: {
          kind: 'openrouter_key_limit', key_fingerprint: verification.key_fingerprint,
          verification_digest: verification.verification_digest, source: 'openrouter_current_key'
        }
      )
      record.save!
      AiLeadEmployee::PilotAuthorizationEvent.create!(pilot_authorization: record, platform_app: actor, action: 'activated')
      record
    end
  end

  private

  attr_reader :account, :conversation, :max_attempts, :max_spend_usd, :expires_at, :platform_app, :verifier,
              :external_owner_approval_reference

  def authorization(current_connection = account.ai_provider_connection, scoped_conversation = conversation)
    @authorization ||= AiLeadEmployee::PilotAuthorization.new(
      account: account, inbox: scoped_conversation.inbox, contact: scoped_conversation.contact, conversation: scoped_conversation,
      ai_provider_connection: current_connection, authorized_by_platform_app: platform_app,
      recipient: scoped_conversation.contact_inbox&.source_id.to_s, control_version: scoped_conversation.control_version,
      provider_configuration_version: current_connection&.configuration_version,
      max_attempts: max_attempts, max_spend_usd: max_spend_usd,
      external_owner_approval_reference: external_owner_approval_reference,
      starts_at: Time.current, expires_at: expires_at
    )
  end

  def exact_scope?(current_connection, scoped_conversation = conversation) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    current_connection&.configured? && scoped_conversation.account_id == account.id && scoped_conversation.ai_active? &&
      scoped_conversation.open? && scoped_conversation.assignee_id.nil? && scoped_conversation.contact_inbox&.source_id.present? &&
      max_attempts.to_i.positive? && max_spend_usd.positive? && expires_at&.future?
  end

  def key_digest(connection)
    Digest::SHA256.hexdigest(connection&.api_key.to_s)
  end

  def default_verifier(connection)
    AiLeadEmployee::AiProvider::OpenRouterKeyLimitVerifier.new(connection: connection)
  end
end
