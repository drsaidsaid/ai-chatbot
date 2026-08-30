# frozen_string_literal: true

FactoryBot.define do
  factory :ai_provider_connection, class: 'AiLeadEmployee::AiProviderConnection' do
    account
    provider { 'openrouter' }
    model { 'openai/gpt-4.1-mini' }
    api_key { 'sk-or-test-secret' }
    status { 'active' }
  end
end
