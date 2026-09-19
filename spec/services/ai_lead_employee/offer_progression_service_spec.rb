# frozen_string_literal: true

require 'active_support/all'

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/offer_progression_service'

RSpec.describe AiLeadEmployee::OfferProgressionService do
  let(:offer_type) { Struct.new(:name, :next_step, keyword_init: true) }
  let(:qualification_type) { Struct.new(:qualification_mode, :next_question, keyword_init: true) }

  it 'keeps answer-only Offers answer-only' do
    result = described_class.new(offer: offer_type.new(name: 'Audit', next_step: { 'kind' => 'answer_only' })).perform

    expect(result).to be_nil
  end

  it 'uses the current configured enquiry prompt' do
    result = described_class.new(
      offer: offer_type.new(name: 'Audit', next_step: { 'kind' => 'enquiry', 'prompt' => 'Would you like to discuss the audit?' })
    ).perform

    expect(result).to eq('Would you like to discuss the audit?')
  end

  it 'renders only an approved http purchase link' do
    result = described_class.new(
      offer: offer_type.new(
        name: 'Course',
        next_step: { 'kind' => 'purchase_link', 'prompt' => 'You can enroll here:', 'url' => 'https://example.test/enroll' }
      )
    ).perform

    expect(result).to eq('You can enroll here: https://example.test/enroll')
    expect(
      described_class.new(
        offer: offer_type.new(name: 'Course', next_step: { 'kind' => 'purchase_link', 'url' => 'javascript:alert(1)' })
      ).perform
    ).to be_nil
  end

  it 'uses one current configured qualification question for a sales-call next step' do
    result = described_class.new(
      offer: offer_type.new(name: 'Coaching', next_step: { 'kind' => 'sales_call' }),
      qualification_result: qualification_type.new(
        qualification_mode: 'enabled', next_question: 'Would you like a sales call?'
      )
    ).perform

    expect(result).to eq('Would you like a sales call?')
  end
end
