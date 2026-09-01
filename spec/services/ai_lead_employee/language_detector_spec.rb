# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::LanguageDetector do
  it 'detects Swahili from common lead phrases' do
    expect(described_class.detect('unaongea kiswahili?')).to eq(:swahili)
    expect(described_class.detect('habari')).to eq(:swahili)
    expect(described_class.detect('naomba maelezo')).to eq(:swahili)
  end

  it 'defaults to English when Swahili evidence is absent' do
    expect(described_class.detect('I run an online course business.')).to eq(:english)
  end
end
