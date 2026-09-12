# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'
require 'uri'

module AiLeadEmployee; end
require_relative '../../../app/services/ai_lead_employee/qualification_amount_parser'
require_relative '../../../app/services/ai_lead_employee/qualification_budget_evidence_extractor'
require_relative '../../../app/services/ai_lead_employee/qualification_evidence_extractor'

# Purchase budget capacity evidence.
RSpec.describe AiLeadEmployee::QualificationEvidenceExtractor do
  it 'records stated purchase capacity without claiming committed funds' do
    statement = 'I need more leads now. I am the owner of the agency and can spend $2500.'
    budget = described_class.new(statement).observations.fetch('budget')

    expect(budget).to include('polarity' => 'positive', 'amount_minor' => 250_000, 'currency' => 'USD', 'basis' => 'capacity')
  end

  it 'keeps an explicitly allocated budget distinct from spending capacity' do
    budget = described_class.new('I have set aside $2500 for this purchase.').observations.fetch('budget')
    expect(budget).to include('polarity' => 'positive', 'amount_minor' => 250_000, 'basis' => 'allocation')
  end

  [
    'My salary is $2500.',
    'Our revenue is $2500 per month.',
    'I can spend $2500 on groceries.',
    'I cannot spend $2500.',
    'I can spend $2500 if my loan is approved.',
    'I can spend $2500 depending on approval.'
  ].each do |statement|
    it "does not treat #{statement.inspect} as positive purchase capacity" do
      budget = described_class.new(statement).observations['budget']
      expect(budget&.fetch('polarity', nil)).not_to eq('positive')
    end
  end

  it 'preserves unknown currency instead of claiming known-currency sufficiency' do
    budget = described_class.new('My budget is 2500.').observations.fetch('budget')
    expect(budget).to include('currency' => nil)
  end

  it 'retains positive purchase capacity when a separate contact clause offers a choice of contact methods' do
    statement = 'I can spend $2500, and I can be reached by email or phone.'
    budget = described_class.new(statement).observations.fetch('budget')

    expect(budget).to include('basis' => 'capacity', 'polarity' => 'positive', 'amount_minor' => 250_000)
  end

  it 'retains a funding condition after a separate contact clause' do
    statement = 'I can spend $2500, and I can be reached by email or phone, depending on approval.'
    budget = described_class.new(statement).observations.fetch('budget')

    expect(budget).to include('polarity' => 'unknown')
  end

  it 'does not drop a funding condition before the spending statement' do
    statement = 'If my loan is approved, I can spend $2500.'
    budget = described_class.new(statement).observations.fetch('budget')

    expect(budget).to include('polarity' => 'unknown')
  end
end
