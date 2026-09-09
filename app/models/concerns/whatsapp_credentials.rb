module WhatsappCredentials
  extend ActiveSupport::Concern

  SECRET_KEYS = %w[api_key app_secret app_secret_key client_secret api_secret webhook_verify_token verification_pin].freeze
  PUBLIC_KEYS = %w[phone_number_id business_account_id source calling_enabled inbound_calls_enabled].freeze

  included do
    serialize :provider_secrets, coder: JSON
    encrypts :provider_secrets if Chatwoot.encryption_configured?
    before_validation :persist_provider_configuration
    before_save :persist_provider_configuration
    validate :credentials_require_encryption
  end

  # Retain the CE provider interface, including its in-place configuration writes.
  # Only the public identifiers are stored in the queryable provider_config JSON.
  def provider_config
    @provider_config ||= self[:provider_config].to_h.merge(provider_secrets.to_h)
  end

  def provider_config=(value)
    config = value.to_h.deep_stringify_keys
    self[:provider_config] = config.except(*SECRET_KEYS)
    self.provider_secrets = provider_secrets.to_h.merge(config.slice(*SECRET_KEYS))
    @provider_config = nil
  end

  def provider_config_changed?
    super || provider_secrets_changed?
  end

  def reload(...)
    @provider_config = nil
    super
  end

  def safe_provider_config
    provider_config.slice(*PUBLIC_KEYS).merge(
      'api_key_configured' => provider_config['api_key'].present?,
      'app_secret_configured' => signing_secrets.present?,
      'webhook_verify_token_configured' => provider_config['webhook_verify_token'].present?
    )
  end

  def signing_secrets
    keys = %w[app_secret app_secret_key client_secret api_secret]
    secrets = provider_config.values_at(*keys).compact_blank
    secrets << GlobalConfigService.load('WHATSAPP_APP_SECRET', nil) if provider_config['source'] == 'embedded_signup'
    secrets.compact_blank.uniq
  end

  private

  def persist_provider_configuration
    self.provider_config = provider_config
  end

  def credentials_require_encryption
    return if provider_secrets.blank? || Chatwoot.encryption_configured?

    errors.add(:provider_config, 'requires configured Active Record encryption before storing credentials')
  end
end
