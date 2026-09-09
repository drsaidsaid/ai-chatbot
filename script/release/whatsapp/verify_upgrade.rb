# This script verifies only disposable migration fixtures, never a deployed account.
database = ActiveRecord::Base.connection_db_config.database
abort 'Use the R03 upgrade test database' unless Rails.env.test? && database == 'ale_release_r03_upgrade'
channel = Channel::Whatsapp.find_by!(phone_number: '+255700000099')
expected = ['legacy-r03-access', 'legacy-r03-signing', 'legacy-r03-verify', 123_456]
raise 'Credential read failed' unless channel.provider_config.values_at('api_key', 'app_secret', 'webhook_verify_token',
                                                                        'verification_pin') == expected

raise 'Management credential read failed' unless channel.business_management_token == 'legacy-r03-management'

connection = ActiveRecord::Base.connection
raw = connection.select_one("SELECT provider_config, provider_secrets, business_management_token FROM channel_whatsapp WHERE id = #{channel.id}")
raise 'Plaintext credentials remain' if raw.to_json.include?('legacy-r03-')

preserved = Channel::Whatsapp.find_by!(phone_number: '+255700000097')
raise 'Encrypted management token changed' unless preserved.business_management_token == 'legacy-r03-encrypted-management'

original_digest = preserved[:provider_config].fetch('legacy_ciphertext_sha256')
unless Digest::SHA256.hexdigest(preserved.read_attribute_before_type_cast(:business_management_token)) == original_digest
  raise 'Existing ciphertext was rewritten'
end

require Rails.root.join('db/migrate/20260910000301_limit_whatsapp_cloud_connections')
connection.transaction do
  migration = LimitWhatsappCloudConnections.new
  migration.migrate(:down)
  connection.execute(<<~SQL.squish)
    INSERT INTO channel_whatsapp (account_id, phone_number, provider, provider_config, provider_secrets, created_at, updated_at)
    SELECT account_id, '+255700000098', provider, provider_config, provider_secrets, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM channel_whatsapp WHERE id = #{channel.id}
  SQL
  begin
    connection.transaction(requires_new: true) { migration.migrate(:up) }
    raise 'Duplicate Cloud connections were accepted'
  rescue ActiveRecord::RecordNotUnique
    raise 'Conflicting data was deleted' unless connection.select_value('SELECT count(*) FROM channel_whatsapp WHERE account_id = 9003') == 2
  end
  raise ActiveRecord::Rollback
end
raise 'Constraint was not restored' unless connection.index_exists?(:channel_whatsapp, :account_id, name: 'index_whatsapp_cloud_one_per_account')

puts 'Legacy credentials decrypt after upgrade and remain encrypted at rest.'
puts 'The unique-connection migration refuses conflicts without deleting either row.'
