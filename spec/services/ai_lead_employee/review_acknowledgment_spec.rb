# frozen_string_literal: true

require 'active_support/all'

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/review_acknowledgment'

RSpec.describe AiLeadEmployee::ReviewAcknowledgment do
  it 'renders the approved fixed acknowledgment for an eligible English Review' do
    content = described_class.new(reason: 'conflicting_knowledge', language: :english).perform

    expect(content).to eq('I cannot give you a confirmed answer yet. I have recorded your question for the team to review.')
  end

  %w[delivery_unknown opted_out stale_control_version launch_gate_not_approved qualification_blocker unsupported_media].each do |reason|
    it "does not render a customer acknowledgment for #{reason}" do
      content = described_class.new(reason: reason, language: :english).perform

      expect(content).to be_nil
    end
  end

  it 'does not render an acknowledgment without a supported Review reason' do
    expect(described_class.new(reason: nil, language: :english).perform).to be_nil
  end

  it 'renders the approved fixed Swahili acknowledgment for provider failure' do
    content = described_class.new(reason: 'provider_failed', language: :swahili).perform

    expect(content).to eq('Bado sina jibu lililothibitishwa. Nimeweka swali lako kwa timu ili ilipitie.')
  end

  [
    ['angry_question', :complaint, :english,
     'I am sorry you have had this experience. I have recorded your complaint for the team to review.'],
    ['angry_question', :complaint, :swahili,
     'Pole kwa hali hii. Nimeweka malalamiko yako kwa timu ili iyapitie.'],
    ['sensitive_question', :refund_request, :english,
     'I have recorded your refund request for the team to review.'],
    ['sensitive_question', :refund_request, :swahili,
     'Nimeweka ombi lako la kurejeshewa fedha kwa timu ili ilipitie.'],
    ['sensitive_question', :support_request, :english,
     'I have recorded your support request for the team to review.'],
    ['sensitive_question', :support_request, :swahili,
     'Nimeweka ombi lako la msaada kwa timu ili ilipitie.']
  ].each do |reason, request_intent, language, expected|
    it "renders the approved #{language} #{request_intent} acknowledgment without a qualification question" do
      content = described_class.new(reason: reason, request_intent: request_intent, language: language).perform

      expect(content).to eq(expected)
    end
  end
end
