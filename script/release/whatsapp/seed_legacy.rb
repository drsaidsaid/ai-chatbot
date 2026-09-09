# Pre-migration fixtures for the isolated R03 credential upgrade proof.
abort 'Use the R03 upgrade test database' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'ale_release_r03_upgrade'
connection = ActiveRecord::Base.connection
abort 'Existing WhatsApp rows are never replaced' unless connection.select_value('SELECT count(*) FROM channel_whatsapp').zero?
connection.execute(File.read(Rails.root.join('script/release/whatsapp/legacy_credentials.sql')))
encrypted = ActiveRecord::Encryption.encryptor.encrypt('legacy-r03-encrypted-management')
config = { legacy_ciphertext_sha256: Digest::SHA256.hexdigest(encrypted) }.to_json
connection.execute(<<~SQL.squish)
  INSERT INTO channel_whatsapp (account_id, phone_number, provider, provider_config, business_management_token, created_at, updated_at)
  VALUES (9004, '+255700000097', 'whatsapp_cloud', #{connection.quote(config)}::jsonb,
          #{connection.quote(encrypted)}, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
SQL
puts 'Synthetic plaintext and already encrypted credential fixtures created.'
