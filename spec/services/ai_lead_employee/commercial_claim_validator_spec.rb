# frozen_string_literal: true

module AiLeadEmployee
end

require_relative '../../../app/services/ai_lead_employee/commercial_claim_validator'

RSpec.describe AiLeadEmployee::CommercialClaimValidator do
  it 'accepts commercial facts copied from the approved answer' do
    expect(
      described_class.new(
        approved_content: 'The course costs TZS 500,000. Enroll at https://example.test/course.',
        candidate_content: 'The price is TZS 500,000. Enroll at https://example.test/course.'
      ).valid?
    ).to be(true)
  end

  it 'rejects an amount or link introduced by provider output' do
    expect(described_class.new(approved_content: 'The course is available.', candidate_content: 'It costs $20.').valid?).to be(false)
    expect(
      described_class.new(approved_content: 'Enrollment is available.', candidate_content: 'Use https://fake.test/pay.').valid?
    ).to be(false)
  end

  it 'rejects a guarantee or eligibility claim absent from the approved answer' do
    expect(
      described_class.new(approved_content: 'We teach the course.', candidate_content: 'Results are guaranteed and everyone is eligible.').valid?
    ).to be(false)
  end

  it 'does not turn a denied guarantee into a positive guarantee' do
    result = described_class.new(
      approved_content: 'We do not offer or imply a guarantee of results.',
      candidate_content: 'Your results are guaranteed.'
    )

    expect(result).not_to be_valid
  end

  it 'does not turn a denied refund into a positive refund claim' do
    result = described_class.new(
      approved_content: 'No refunds are available after enrollment.',
      candidate_content: 'Refunds are available after enrollment.'
    )

    expect(result).not_to be_valid
  end

  it 'recognizes negation that follows the controlled claim term' do
    expect(
      described_class.new(
        approved_content: 'Refunds are not available after enrollment.',
        candidate_content: 'Refunds are available after enrollment.'
      )
    ).not_to be_valid
    expect(
      described_class.new(
        approved_content: 'Eligibility is not guaranteed.',
        candidate_content: 'Eligibility is guaranteed.'
      )
    ).not_to be_valid
  end

  it 'does not turn denied Swahili refund, guarantee, or eligibility claims positive' do
    expectations = [
      ['Marejesho hayapatikani baada ya kujiandikisha.', 'Marejesho yanapatikana baada ya kujiandikisha.'],
      ['Matokeo hayajahakikishwa.', 'Matokeo yamehakikishwa.'],
      ['Hustahili kujiunga.', 'Unastahili kujiunga.']
    ]

    expectations.each do |approved_content, candidate_content|
      expect(described_class.new(approved_content: approved_content, candidate_content: candidate_content)).not_to be_valid
    end
  end
end
