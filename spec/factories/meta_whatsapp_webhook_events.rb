# frozen_string_literal: true

FactoryBot.define do
  factory :meta_whatsapp_webhook_event do
    account
    inbox
    channel_whatsapp { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
    provider_event_id { SecureRandom.uuid }
    event_kind { 'message.text' }
    payload { { 'id' => provider_event_id } }
  end
end
