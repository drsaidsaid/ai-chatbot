# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::SwahiliMoneyParser do
  {
    'elfu hamsini' => [50_000],
    'laki mbili' => [200_000],
    'elfu hamsini na tano' => [55_000],
    'laki mbili na elfu hamsini' => [250_000]
  }.each do |phrase, expected|
    it "parses the complete supported monetary phrase #{phrase.inspect}" do
      expect(described_class.amounts(phrase)).to eq(expected)
    end
  end

  [
    'elfu sabini na saba',
    'laki saba na elfu hamsini',
    'laki mbili na nusu',
    'elfu hamsini na mia tano',
    'laki mbili na elfu hamsini na mia tano',
    'milioni moja na laki mbili',
    'laki mbili na500',
    'elfu hamsini na5'
  ].each do |phrase|
    it "quarantines the complete unsupported monetary phrase #{phrase.inspect}" do
      expect(described_class.amounts(phrase)).to be_empty
      expect(described_class).to be_monetary_language(phrase)
      expect(described_class).to be_unresolved(phrase)
    end
  end

  it 'reports any unresolved span while retaining valid spans for diagnostics' do
    phrase = 'elfu hamsini au laki saba'

    expect(described_class.amounts(phrase)).to eq([50_000])
    expect(described_class).to be_unresolved(phrase)
  end

  it 'keeps multiple fully valid spans available for conflict handling' do
    phrase = 'elfu hamsini au laki mbili'

    expect(described_class.amounts(phrase)).to eq([50_000, 200_000])
    expect(described_class).not_to be_unresolved(phrase)
  end
end
