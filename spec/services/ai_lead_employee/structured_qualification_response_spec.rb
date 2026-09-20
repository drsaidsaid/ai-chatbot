# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::StructuredQualificationResponse do
  let(:account) { create(:account) }
  let(:offer) do
    AiLeadEmployee::Offer.create!(
      account: account, name: 'Configured service', currency: 'TZS', enabled: true,
      configuration: {
        'questions' => [
          { 'key' => 'business_status', 'meaning' => 'Current business status', 'answer_type' => 'choice',
            'options' => %w[running not_running], 'enabled' => true, 'required' => true },
          { 'key' => 'monthly_business_revenue_tzs', 'meaning' => 'Current monthly business revenue',
            'answer_type' => 'money', 'period' => 'monthly', 'enabled' => true, 'required' => true },
          { 'key' => 'employee_count', 'meaning' => 'Current number of employees',
            'answer_type' => 'number', 'enabled' => true, 'required' => false },
          { 'key' => 'revenue_goal_tzs', 'meaning' => 'Future monthly revenue goal',
            'answer_type' => 'money', 'period' => 'monthly', 'enabled' => true, 'required' => false },
          { 'key' => 'expert_willingness', 'meaning' => 'Willingness to speak with an expert',
            'answer_type' => 'boolean', 'enabled' => true, 'required' => true },
          { 'key' => 'sales_call_agreement', 'meaning' => 'Call agreement', 'answer_type' => 'boolean',
            'enabled' => true, 'required' => true }
        ],
        'next_step' => { 'kind' => 'sales_call', 'agreement_field' => 'sales_call_agreement' }
      }
    )
  end
  let(:lead_text) do
    'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni. ' \
      'Mapato yangu ni shilingi 800,000 kwa mwezi, na lengo ni kufikia milioni 3. ' \
      'Je, programu yenu inaweza kunisaidia? Tafadhali nijibu kwa Kiswahili.'
  end
  let(:message) { create(:message, account: account, content: lead_text) }

  it 'accepts asserted full-clause candidates for arbitrary configured fields' do
    result = described_class.new(
      offer: offer,
      incoming_message: message,
      content: {
        reply: 'Ndiyo, programu inaweza kusaidia kulingana na chanzo kilichoidhinishwa.',
        observations: [
          { key: 'business_status', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
            typed_value: 'running', asserted: true, certainty: 'certain' },
          { key: 'monthly_business_revenue_tzs', quote: 'Mapato yangu ni shilingi 800,000 kwa mwezi',
            typed_value: 80_000_000, asserted: true, certainty: 'certain' }
        ],
        localized_prompts: { expert_willingness: 'Je, ungependa kuzungumza na mtaalamu?' }
      }.to_json
    ).perform

    expect(result).not_to be_malformed
    expect(result.reply).to eq('Ndiyo, programu inaweza kusaidia kulingana na chanzo kilichoidhinishwa.')
    expect(result.observations).to include(
      'business_status' => include('typed_value' => 'running', 'quote' => 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.'),
      'monthly_business_revenue_tzs' => include('typed_value' => 80_000_000, 'currency' => 'TZS', 'period' => 'monthly')
    )
    expect(result.localized_prompts).to eq('expert_willingness' => 'Je, ungependa kuzungumza na mtaalamu?')
  end

  it 'rejects unsafe or unsupported candidates without exposing provider garbage' do
    result = described_class.new(
      offer: offer,
      incoming_message: message,
      content: {
        reply: 'Jibu lililoidhinishwa.',
        observations: [
          { key: 'monthly_business_revenue_tzs', quote: 'lengo ni kufikia milioni 3',
            typed_value: 300_000_000, asserted: true, certainty: 'certain' },
          { key: 'monthly_business_revenue_tzs', quote: 'Mapato yangu ni shilingi 800,000 kwa mwezi',
            typed_value: 300_000_000, asserted: true, certainty: 'certain' },
          { key: 'expert_willingness', quote: 'Je, programu yenu inaweza kunisaidia?',
            typed_value: true, asserted: true, certainty: 'certain' },
          { key: 'sales_call_agreement', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
            typed_value: true, asserted: true, certainty: 'certain' },
          { key: 'unknown', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
            typed_value: 'running', asserted: true, certainty: 'certain' },
          'not-a-candidate'
        ],
        localized_prompts: { bogus: 'Prompt', business_status: { text: 'Prompt' } }
      }.to_json
    ).perform

    expect(result).not_to be_malformed
    expect(result.observations).to be_empty
    expect(result.localized_prompts).to be_empty
  end

  it 'rejects duplicate conflicting candidates for the same field instead of letting the last one win' do
    result = described_class.new(
      offer: offer,
      incoming_message: message,
      content: {
        reply: 'Jibu lililoidhinishwa.',
        observations: [
          { key: 'business_status', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
            typed_value: 'running', asserted: true, certainty: 'certain' },
          { key: 'business_status', quote: 'Ndiyo, nina biashara ya kufundisha watu ujuzi mtandaoni.',
            typed_value: 'not_running', asserted: true, certainty: 'certain' }
        ],
        localized_prompts: {}
      }.to_json
    ).perform

    expect(result.observations).not_to include('business_status')
  end

  it 'uses the containing Lead clause so short quotes cannot strip negation or future context' do
    message.update!(content: 'I do not have 5 employees yet. My goal is TZS 3,000,000 per month.')

    result = described_class.new(
      offer: offer,
      incoming_message: message,
      content: {
        reply: 'Thanks.',
        observations: [
          { key: 'employee_count', quote: '5 employees',
            typed_value: 5, asserted: true, certainty: 'certain' },
          { key: 'monthly_business_revenue_tzs', quote: 'TZS 3,000,000 per month',
            typed_value: 300_000_000, asserted: true, certainty: 'certain' },
          { key: 'revenue_goal_tzs', quote: 'My goal is TZS 3,000,000 per month',
            typed_value: 300_000_000, asserted: true, certainty: 'certain' }
        ],
        localized_prompts: {}
      }.to_json
    ).perform

    expect(result.observations).to include('revenue_goal_tzs')
    expect(result.observations).not_to include('employee_count', 'monthly_business_revenue_tzs')
  end

  it 'supports arbitrary configured number fields from asserted clauses' do
    message.update!(content: 'We currently have 5 employees.')

    result = described_class.new(
      offer: offer,
      incoming_message: message,
      content: {
        reply: 'Thanks.',
        observations: [
          { key: 'employee_count', quote: 'We currently have 5 employees',
            typed_value: 5, asserted: true, certainty: 'certain' }
        ],
        localized_prompts: {}
      }.to_json
    ).perform

    expect(result.observations).to include('employee_count' => include('typed_value' => 5))
  end

  it 'handles missing or disabled Offer context as malformed rather than calling nil questions' do
    result = described_class.new(
      offer: nil,
      incoming_message: message,
      content: { reply: 'Thanks.', observations: [{ key: 'business_status', quote: 'anything' }] }.to_json
    ).perform

    expect(result).to have_attributes(reply: nil, observations: {}, localized_prompts: {}, malformed: true)
  end

  it 'marks malformed structured output without returning the raw payload as a reply' do
    result = described_class.new(offer: offer, incoming_message: message, content: 'not json').perform

    expect(result).to have_attributes(reply: nil, observations: {}, localized_prompts: {}, malformed: true)
  end
end
