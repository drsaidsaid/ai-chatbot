# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AiProvider::ClientFactory do
  describe '.for' do
    it 'classifies a missing provider connection as disabled configuration state' do
      account = create(:account)

      expect { described_class.for(account: account) }
        .to raise_error(AiLeadEmployee::AiProvider::DisabledFailure) do |error|
          expect(error.failure_class).to eq('provider_disabled')
        end
    end
  end
end
