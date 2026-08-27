# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeItem do
  it 'preserves the persisted source kind values and appends new claim types' do
    expect(described_class.source_kinds).to include(
      'faq' => 0,
      'offer' => 1,
      'pricing' => 2,
      'supporting_document' => 3,
      'objection' => 4,
      'policy' => 5,
      'refund' => 6,
      'guarantee' => 7,
      'eligibility' => 8
    )
  end
end
