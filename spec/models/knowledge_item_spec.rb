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

  it 'retains the exact approved answer in immutable approval revisions' do
    item = create(:knowledge_item, status: :draft, approved_at: nil, metadata: {})

    item.approve!
    first_revision = item.metadata.fetch('approval_revisions').last
    item.update!(answer: 'An unapproved replacement answer')

    expect(first_revision).to include(
      'question' => 'Do you offer consulting?',
      'answer' => 'Yes, we offer consulting for qualified businesses.',
      'source_kind' => 'faq',
      'source_reference' => item.metadata.fetch('source_reference')
    )
    expect(item.reload.metadata.fetch('approval_revisions').last).to eq(first_revision)
    expect(item).not_to be_verified_source_reference
  end
end
