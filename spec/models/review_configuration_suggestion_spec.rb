# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewConfigurationSuggestion do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account, assignee: user) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: conversation.inbox) }
  let(:review) do
    create(:human_review_request, account: account, conversation: conversation, lead_message: message)
  end

  it 'requires exactly one source and the exact Review evidence message' do
    suggestion = described_class.new(
      account: account,
      human_review_request: review,
      conversation: conversation,
      source_message: create(:message, account: account, conversation: conversation, inbox: conversation.inbox),
      proposed_by_user: user,
      category: :poor_fit,
      status: :pending,
      suggestion: 'Review the fit rule.',
      evidence: review.question
    )

    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:source_message]).to include('must be the Review source message')

    suggestion.source_message = message
    suggestion.proposed_by_user = create(:user)
    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:proposed_by_user]).to include('must belong to the same Business Account')

    suggestion.proposed_by_user = user
    suggestion.lead_handoff = create(
      :lead_handoff,
      account: account,
      conversation: conversation,
      contact: conversation.contact,
      lead_qualification: create(:lead_qualification, account: account, contact: conversation.contact)
    )
    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:base]).to include('must belong to exactly one feedback source')
  end

  it 'requires a Lead Handoff suggestion to preserve its account, conversation, and Offer source', :aggregate_failures do
    offer = AiLeadEmployee::Offer.create!(account: account, name: 'Offer', currency: 'TZS')
    qualification = create(:lead_qualification, account: account, contact: conversation.contact, offer: offer)
    handoff = create(
      :lead_handoff,
      account: account,
      conversation: conversation,
      contact: conversation.contact,
      lead_qualification: qualification
    )
    other_account = create(:account)
    other_offer = AiLeadEmployee::Offer.create!(account: other_account, name: 'Other', currency: 'TZS')
    suggestion = described_class.new(
      account: account,
      lead_handoff: handoff,
      conversation: conversation,
      offer: other_offer,
      source_message: message,
      proposed_by_user: user,
      category: :not_ready,
      status: :pending,
      suggestion: 'Review readiness.',
      evidence: handoff.qualification_snapshot.to_json
    )

    expect(suggestion).not_to be_valid
    expect(suggestion.errors[:offer]).to include('must belong to the same Business Account', 'must match the feedback source')
    expect(suggestion.errors[:source_message]).to include('is not permitted for a Lead Handoff')
  end
end
