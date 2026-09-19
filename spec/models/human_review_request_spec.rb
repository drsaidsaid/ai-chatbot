# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HumanReviewRequest do
  let(:account) { create(:account) }
  let(:operator) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: operator) }
  let(:lead_message) do
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, message_type: :incoming)
  end
  let(:review_request) do
    create(:human_review_request, account: account, conversation: conversation, lead_message: lead_message)
  end

  it 'rejects resolution by an operator who was reassigned before the mutation lock' do
    replacement = create(:user, account: account, role: :agent)
    conversation.update!(assignee: replacement)

    expect do
      review_request.resolve_with!(answer: 'Private operator note', operator: operator, resolution_kind: 'internal_note')
    end.to raise_error(Pundit::NotAuthorizedError)

    expect(review_request.reload).to be_open
    expect(conversation.messages.where(content: 'Private operator note')).to be_empty
  end

  it 'rejects a knowledge proposal after the operator membership is revoked' do
    review_request.resolve_with!(answer: 'Private operator note', operator: operator, resolution_kind: 'internal_note')
    AccountUser.find_by!(account: account, user: operator).destroy!

    expect do
      review_request.propose_knowledge!(
        proposer: operator,
        source_kind: 'refund',
        title: 'Refund guidance',
        answer: 'Refund requests are assessed under the published policy.'
      )
    end.to raise_error(Pundit::NotAuthorizedError)

    expect(review_request.reload.knowledge_item).to be_nil
  end

  it 'locks the Conversation before the Review mutation' do
    lock_queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      lock_queries << payload[:sql] if payload[:sql].include?('FOR ')
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      review_request.resolve_with!(answer: 'Private operator note', operator: operator, resolution_kind: 'internal_note')
    end

    conversation_lock = lock_queries.index { |sql| sql.include?('FROM "conversations"') && sql.include?('FOR NO KEY UPDATE') }
    review_lock = lock_queries.index { |sql| sql.include?('FROM "human_review_requests"') && sql.include?('FOR UPDATE') }

    expect(conversation_lock).not_to be_nil
    expect(review_lock).not_to be_nil
    expect(conversation_lock).to be < review_lock
  end

  it 'takes knowledge authority and Account locks before Conversation when proposing knowledge' do
    review_request.resolve_with!(answer: 'Private operator note', operator: operator, resolution_kind: 'internal_note')
    queries = []
    subscriber = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql]
    end

    ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
      review_request.propose_knowledge!(
        proposer: operator,
        source_kind: 'refund',
        title: 'Refund guidance',
        answer: 'Refund requests are assessed under the published policy.'
      )
    end

    authority_lock = queries.index { |sql| sql.include?('pg_advisory_xact_lock') }
    account_lock = queries.index { |sql| sql.include?('FROM "accounts"') && sql.include?('FOR KEY SHARE') }
    conversation_lock = queries.index { |sql| sql.include?('FROM "conversations"') && sql.include?('FOR NO KEY UPDATE') }
    review_lock = queries.index { |sql| sql.include?('FROM "human_review_requests"') && sql.include?('FOR UPDATE') }

    expect([authority_lock, account_lock, conversation_lock, review_lock]).to all(be_present)
    expect(authority_lock).to be < account_lock
    expect(account_lock).to be < conversation_lock
    expect(conversation_lock).to be < review_lock
  end
end
