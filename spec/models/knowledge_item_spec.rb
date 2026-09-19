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

  it 'snapshots and verifies every metadata field that controls retrieval authority' do
    account = create(:account)
    authority_metadata = {
      'offer_ids' => [123],
      'language' => 'swahili',
      'expires_at' => 1.day.from_now.iso8601,
      'stale' => false
    }
    item = create(:knowledge_item, account: account, status: :draft, approved_at: nil, metadata: authority_metadata)

    item.approve!

    expect(item.metadata.fetch('approval_revisions').last.fetch('authority_metadata')).to eq(authority_metadata)
    expect(item).to be_verified_source_reference

    %w[offer_ids language expires_at stale].each do |field|
      changed_metadata = item.metadata.deep_dup
      changed_metadata[field] = field == 'offer_ids' ? [] : "changed-#{field}"
      item.update!(metadata: changed_metadata)

      expect(item).not_to be_verified_source_reference
      item.reload.update!(metadata: item.metadata.merge(field => authority_metadata[field]))
    end
  end
end
