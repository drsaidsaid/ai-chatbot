# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AiProviderUsage do
  it 'rejects usage attributed to a different Business Account than its connection' do
    connection = create(:ai_provider_connection)
    usage = described_class.new(
      account: create(:account),
      ai_provider_connection: connection,
      configuration_version: connection.configuration_version,
      purpose: 'answer',
      period_on: Time.current.utc.to_date,
      status: 'completed',
      requested_output_tokens: connection.reply_token_limit,
      started_at: Time.current
    )

    expect(usage).not_to be_valid
    expect(usage.errors[:account]).to include('must match the AI provider connection Business Account')
  end

  it 'enforces the same account boundary through the separate usage-ledger model' do
    ledger_connection = AiLeadEmployee::AiProviderLedgerConnection.new(id: 123, account_id: 456)
    usage = AiLeadEmployee::AiProviderLedgerUsage.new(
      account_id: 789,
      ai_provider_connection: ledger_connection,
      configuration_version: 1,
      purpose: 'answer',
      period_on: Time.current.utc.to_date,
      requested_output_tokens: 512,
      started_at: Time.current
    )

    expect(usage).not_to be_valid
    expect(usage.errors[:account_id]).to include('must match the AI provider connection Business Account')
  end
end
