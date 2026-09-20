# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::ExactOfferContextResolver do
  let(:account) { create(:account) }

  it 'selects the one enabled Offer named as a complete phrase' do
    offer = create_offer(account: account, name: 'Online Profits University')

    result = described_class.new(
      account: account,
      message: 'What does Online Profits University help people do?'
    ).perform

    expect(result).to eq(offer)
  end

  it 'does not select an Offer when exact mentions are ambiguous' do
    create_offer(account: account, name: 'Online Profits')
    create_offer(account: account, name: 'Online Profits University')

    result = described_class.new(account: account, message: 'Tell me about Online Profits University.').perform

    expect(result).to be_nil
  end

  it 'does not select disabled Offers or partial-name matches' do
    disabled = create_offer(account: account, name: 'Online Profits University', enabled: false)
    enabled = create_offer(account: account, name: 'Profit University')

    result = described_class.new(account: account, message: 'Tell me about Online Profits University.').perform

    expect(result).not_to eq(disabled)
    expect(result).not_to eq(enabled)
    expect(result).to be_nil
  end

  it 'does not access a same-named Offer owned by another Business Account' do
    other_offer = create_offer(account: create(:account), name: 'Online Profits University')

    result = described_class.new(account: account, message: 'Tell me about Online Profits University.').perform

    expect(result).to be_nil
    expect(result).not_to eq(other_offer)
  end

  def create_offer(account:, name:, enabled: true)
    AiLeadEmployee::Offer.create!(account: account, name: name, currency: 'USD', enabled: enabled)
  end
end
