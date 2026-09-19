# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OfferAnswerContext do
  it 'accepts only the current selected Offer revision' do
    account = create(:account)
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Coaching', currency: 'USD', enabled: true)
    conversation = create(:conversation, account: account, offer: offer)
    context = described_class.capture(conversation: conversation, offer: offer)

    expect(described_class.new(conversation: conversation, context: context).failure_code).to be_nil

    offer.update!(configuration_version: offer.configuration_version + 1)
    expect(described_class.new(conversation: conversation, context: context).failure_code).to eq('offer_configuration_changed')
  end
end
