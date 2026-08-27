# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KnowledgeDocument do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  it 'keeps draft publish archive revisions with the account editor' do
    document = described_class.new(account: account)
    document.save_draft!(
      attributes: {
        title: 'Everything about Online Profits',
        body: 'Company context and services',
        used_by_ai_employee: true,
        general_question_access: true
      },
      editor: admin
    )

    expect(document).to be_draft
    expect(document.revisions.last['event']).to eq('created')

    document.publish!(editor: admin)
    expect(document).to be_published
    expect(document.published_at).to be_present

    document.archive!(editor: admin)
    expect(document).to be_archived
    expect(document.revisions.pluck('event')).to include('published', 'archived')
  end

  it 'is eligible for AI Employee retrieval only when published and access is enabled' do
    eligible = create(:knowledge_document, account: account)
    create(:knowledge_document, account: account, status: :draft)
    create(:knowledge_document, account: account, used_by_ai_employee: false)
    create(:knowledge_document, account: account, general_question_access: false)

    expect(account.knowledge_documents.eligible_for_ai_employee).to contain_exactly(eligible)
  end

  it 'requires a fresh publication after content changes before AI retrieval' do
    document = create(:knowledge_document, account: account)

    expect(document).to be_verified_source_reference

    document.update!(body: 'Changed after publication')

    expect(document).not_to be_verified_source_reference
    document.publish!(editor: admin)
    expect(document).to be_verified_source_reference
  end

  it 'rejects an editor from another Business Account' do
    other_admin = create(:user, account: create(:account), role: :administrator)

    document = build(:knowledge_document, account: account, last_editor: other_admin)

    expect(document).not_to be_valid
    expect(document.errors[:last_editor]).to include('must belong to the document account')
  end
end
