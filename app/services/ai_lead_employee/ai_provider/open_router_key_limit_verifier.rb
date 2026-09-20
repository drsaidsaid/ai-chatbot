# frozen_string_literal: true

class AiLeadEmployee::AiProvider::OpenRouterKeyLimitVerifier
  Result = Data.define(:limit_usd, :remaining_usd, :key_expires_at, :key_fingerprint, :verification_digest, :verified_at)
  ENDPOINT = 'https://openrouter.ai/api/v1/key'

  def initialize(connection:)
    @connection = connection
  end

  def perform # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    response = HTTParty.get(ENDPOINT, headers: { 'Authorization' => "Bearer #{connection.api_key}" }, timeout: 15)
    raise AiLeadEmployee::AiProvider::PilotAdmissionFailure, 'Provider key limit verification failed' unless response.success?

    data = response.parsed_response.to_h.fetch('data', {}).to_h
    limit = decimal(data['limit'])
    remaining = decimal(data['limit_remaining'])
    raise AiLeadEmployee::AiProvider::PilotAdmissionFailure, 'Provider key has no verified USD limit' unless limit&.positive? && remaining&.positive?

    reject_resetting_limit!(data)

    key_expires_at = Time.zone.parse(data['expires_at'].to_s) if data['expires_at'].present?
    reject_expired_key!(key_expires_at)

    sanitized = {
      source: 'openrouter_current_key', limit_usd: limit.to_s('F'), remaining_usd: remaining.to_s('F'),
      limit_reset: data['limit_reset'], expires_at: data['expires_at'], label: data['label']
    }.compact
    Result.new(
      limit_usd: limit, remaining_usd: remaining, key_expires_at: key_expires_at,
      key_fingerprint: "sha256:#{Digest::SHA256.hexdigest(connection.api_key)}",
      verification_digest: "sha256:#{Digest::SHA256.hexdigest(JSON.generate(sanitized.sort.to_h))}",
      verified_at: Time.current
    )
  rescue KeyError, JSON::ParserError, TypeError
    raise AiLeadEmployee::AiProvider::PilotAdmissionFailure, 'Provider key limit verification response is invalid'
  end

  private

  attr_reader :connection

  def decimal(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def reject_resetting_limit!(data)
    return if data['limit_reset'].blank?

    raise AiLeadEmployee::AiProvider::PilotAdmissionFailure, 'Provider key limit must not reset during the pilot'
  end

  def reject_expired_key!(key_expires_at)
    return unless key_expires_at&.past?

    raise AiLeadEmployee::AiProvider::PilotAdmissionFailure, 'Provider key expires before the pilot can start'
  end
end
