-- Synthetic pre-encryption row for ale_release_r03_upgrade only. No live account.
INSERT INTO channel_whatsapp (account_id, phone_number, provider, provider_config, business_management_token, created_at, updated_at)
VALUES (9003, '+255700000099', 'whatsapp_cloud',
        '{"phone_number_id":"3099","business_account_id":"9099","api_key":"legacy-r03-access","app_secret":"legacy-r03-signing","webhook_verify_token":"legacy-r03-verify","verification_pin":123456}',
        'legacy-r03-management', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
