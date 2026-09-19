# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OfferConfigurationWriter do
  let(:account) { create(:account) }
  let(:base_attributes) do
    {
      name: 'Course', currency: 'USD', enabled: true, qualification_mode: 'disabled',
      questions: [], budget_ranges: [], rules: [], score_weights: {},
      score_thresholds: { qualified: 60, highly_qualified: 80 }
    }
  end

  it 'persists the configured prompt and trusted link in the Offer revision' do
    offer = described_class.new(
      offer: account.qualification_offers.new,
      attributes: base_attributes.merge(
        next_step: { kind: 'purchase_link', prompt: 'Enroll here:', url: 'https://example.test/course' }
      )
    ).perform

    expect(offer.next_step).to eq(
      'kind' => 'purchase_link', 'prompt' => 'Enroll here:', 'url' => 'https://example.test/course'
    )
    expect(offer.configuration_revisions.last.snapshot['next_step']).to eq(offer.next_step)
  end

  it 'rejects an untrusted next-step link' do
    expect do
      described_class.new(
        offer: account.qualification_offers.new,
        attributes: base_attributes.merge(next_step: { kind: 'purchase_link', url: 'javascript:alert(1)' })
      ).perform
    end.to raise_error(ArgumentError, 'Next-step link must use HTTP or HTTPS')
  end
end
