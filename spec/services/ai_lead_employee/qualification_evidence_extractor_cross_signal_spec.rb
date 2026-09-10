# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'
require 'uri'

module AiLeadEmployee; end
require_relative '../../../app/services/ai_lead_employee/qualification_amount_parser'
require_relative '../../../app/services/ai_lead_employee/qualification_budget_evidence_extractor'
require_relative '../../../app/services/ai_lead_employee/qualification_evidence_extractor'

RSpec.describe AiLeadEmployee::QualificationEvidenceExtractor do
  it 'does not treat a budget correction as an answer to the business question' do
    facts = described_class.new('Correction, I have no budget.', answered_signal: 'business_type').observations

    expect(facts['budget']).to include('polarity' => 'negative')
    expect(facts).not_to have_key('business_type')
  end

  it 'retains a genuine descriptive answer to the business question' do
    facts = described_class.new('Bookkeeping', answered_signal: 'business_type').observations

    expect(facts['business_type']).to include('polarity' => 'positive', 'value' => 'bookkeeping')
  end

  it 'retains a separate explicit business assertion alongside a budget correction' do
    facts = described_class.new('Correction, I have no budget. I run a salon.', answered_signal: 'business_type').observations

    expect(facts['budget']).to include('polarity' => 'negative')
    expect(facts['business_type']).to include('polarity' => 'positive', 'value' => 'salon')
  end
end
