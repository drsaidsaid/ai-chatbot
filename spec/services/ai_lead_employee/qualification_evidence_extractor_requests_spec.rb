# frozen_string_literal: true

require 'spec_helper'
require 'active_support/all'
require 'uri'

module AiLeadEmployee; end
require_relative '../../../app/services/ai_lead_employee/qualification_amount_parser'
require_relative '../../../app/services/ai_lead_employee/qualification_budget_evidence_extractor'
require_relative '../../../app/services/ai_lead_employee/qualification_evidence_extractor'

RSpec.describe AiLeadEmployee::QualificationEvidenceExtractor do
  ['Tell me about your course.', 'Please explain your business.'].product(%w[business_type problem]).each do |request, signal|
    it "does not turn #{request.inspect} into an answer about #{signal}" do
      expect(described_class.new(request, answered_signal: signal).observations).to be_empty
    end
  end

  ['Please tell me about your course.', 'Explain your pricing.', 'Thanks. Tell me about your course.'].each do |request|
    it "does not borrow business-question context for #{request.inspect}" do
      expect(described_class.new(request, answered_signal: 'business_type').observations).to be_empty
    end
  end

  [['business_type', 'Bookkeeping'], ['problem', 'Finding new customers'],
   ['problem', 'Customer acquisition'], ['problem', 'Kupata wateja wapya']].each do |signal, answer|
    it "preserves the descriptive #{signal} answer #{answer.inspect}" do
      expect(described_class.new(answer, answered_signal: signal).observations[signal]).to include('polarity' => 'positive')
    end
  end

  ['Tell me about your course. I run a salon.', 'I run a salon. Please explain your business.'].each do |message|
    it "retains the explicit business assertion alongside #{message.inspect}" do
      expect(described_class.new(message, answered_signal: 'business_type').observations['business_type']).to include(
        'polarity' => 'positive', 'value' => 'salon'
      )
    end
  end
end
