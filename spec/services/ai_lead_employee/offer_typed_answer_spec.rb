# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::OfferTypedAnswer do
  let(:question) { { 'answer_type' => 'boolean' } }

  it 'leaves a compound affirmative for structured interpretation' do
    answer = described_class.new(
      question: question,
      content: 'Ndiyo, nataka kutumia utaalamu wangu. Nina biashara tayari.',
      currency: 'TZS'
    )

    expect(answer.observation).to be_nil
    expect(answer).to be_compound_boolean_candidate
  end

  it 'does not coerce an affirmative preamble with a later refusal' do
    english = described_class.new(question: question, content: 'Yes, I understand. Do not call me.', currency: 'TZS')
    swahili = described_class.new(
      question: question, content: 'Ndiyo, nimeelewa. Sitaki kupigiwa simu.', currency: 'TZS'
    )

    expect(english.observation).to be_nil
    expect(swahili.observation).to be_nil
    expect(english).to be_compound_boolean_candidate
    expect(swahili).to be_compound_boolean_candidate
  end

  it 'keeps a bare affirmative deterministic' do
    answer = described_class.new(question: question, content: 'Ndiyo.', currency: 'TZS')

    expect(answer.observation).to include('typed_value' => true)
  end
end
