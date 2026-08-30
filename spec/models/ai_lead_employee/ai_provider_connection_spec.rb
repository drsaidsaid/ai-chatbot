# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AiProviderConnection do
  it 'does not allow raw credentials to be stored without Active Record encryption' do
    allow(Chatwoot).to receive(:encryption_configured?).and_return(false)

    connection = build(:ai_provider_connection, api_key: 'sk-or-plaintext-risk')

    expect(connection).not_to be_valid
    expect(connection.errors[:api_key]).to include('cannot be stored until Active Record encryption is configured')
  end
end
