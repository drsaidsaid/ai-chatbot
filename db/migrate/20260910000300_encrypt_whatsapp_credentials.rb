class EncryptWhatsappCredentials < ActiveRecord::Migration[7.1]
  SECRET_KEYS = %w[api_key app_secret app_secret_key client_secret api_secret webhook_verify_token verification_pin].freeze

  def up
    add_column :channel_whatsapp, :provider_secrets, :text
    connection.select_all('SELECT id, provider_config, business_management_token FROM channel_whatsapp').each do |row|
      encrypt_configuration(row)
      encrypt_management_token(row)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Restore a verified backup; do not write WhatsApp credentials back to plaintext'
  end

  private

  def encrypt_configuration(row)
    config = JSON.parse(row['provider_config'] || '{}')
    secrets = config.slice(*SECRET_KEYS)
    return if secrets.empty?

    require_encryption!
    encrypted = ActiveRecord::Encryption.encryptor.encrypt(secrets.to_json)
    execute <<~SQL.squish
      UPDATE channel_whatsapp
      SET provider_config = #{connection.quote(config.except(*SECRET_KEYS).to_json)}::jsonb,
          provider_secrets = #{connection.quote(encrypted)}
      WHERE id = #{connection.quote(row['id'])}
    SQL
  end

  def encrypt_management_token(row)
    token = row['business_management_token']
    return if token.blank? || ActiveRecord::Encryption.encryptor.encrypted?(token)

    # Older CE installations could write this field before encryption was configured.
    require_encryption!
    encrypted = ActiveRecord::Encryption.encryptor.encrypt(token)
    execute <<~SQL.squish
      UPDATE channel_whatsapp SET business_management_token = #{connection.quote(encrypted)}
      WHERE id = #{connection.quote(row['id'])}
    SQL
  end

  def require_encryption!
    raise 'Configure Active Record encryption before migrating WhatsApp credentials' unless Chatwoot.encryption_configured?
  end
end
