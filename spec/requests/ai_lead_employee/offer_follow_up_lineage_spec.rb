# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer follow-up attempt history', type: :request do
  include_context 'with Offer qualification requests'

  def schedule(conversation)
    result = AiLeadEmployee::QualificationService.new(conversation: conversation).perform
    AiLeadEmployee::FollowUpScheduler.new(conversation: conversation, qualification_result: result).perform.first
  end

  def initial_follow_up
    offer = r09_create_offer
    conversation = r09_conversation(offer: offer)
    [offer, conversation, schedule(conversation)]
  end

  it 'replaces never-admitted context while preserving the predecessor and the stage budget across revisions' do
    offer, conversation, first = initial_follow_up
    original = first.attributes.slice('content', 'question_text', 'qualification_context', 'conversation_id')
    current = first
    3.times do |revision|
      r09_update_offer(offer, name: "Revision #{revision}")
      expect(response).to have_http_status(:success)
      offer = response.parsed_body
      successor = schedule(conversation)
      verify_replacement_link(current, successor)
      current = successor
    end
    expect(first.reload.attributes.slice(*original.keys)).to eq(original)
    expect(current.follow_up_attempt_id).to eq(first.follow_up_attempt_id)
    expect(current.follow_up_attempt.current_follow_up_id).to eq(current.id)
    expect(LeadFollowUpAttempt.where(account: account, contact: r09_lead).count).to eq(1)
    expect(LeadFollowUp.where(follow_up_attempt_id: first.follow_up_attempt_id, superseded_at: nil).count).to eq(1)
  end

  it 'does not let an old materialization job send its successor' do
    offer, conversation, first = initial_follow_up
    first.update!(scheduled_at: 1.minute.ago)
    r09_update_offer(offer, name: 'New context')
    successor = schedule(conversation)

    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: first).perform

    expect(first.reload.message_id).to be_nil
    expect(successor.reload.message_id).to be_nil
    expect(first).to be_cancelled
  end

  it 'copies the exact frozen context and question key into the materialized Message and event' do
    _offer, _conversation, follow_up = initial_follow_up
    follow_up.update!(scheduled_at: 1.minute.ago)
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform

    message = follow_up.reload.message
    expect(follow_up.question_key).to eq('budget')
    expect(follow_up.qualification_context).to include('next_question_key' => 'budget')
    expect(message.additional_attributes.dig('ai_lead_employee', 'qualification_context')).to eq(follow_up.qualification_context)
    expect(OutboxEvent.find_by!(aggregate: message).payload['qualification_context']).to eq(follow_up.qualification_context)
  end

  %w[admitted accepted unknown failed blocked].each do |state|
    it "does not reopen a #{state} attempt after an Offer revision" do
      offer, conversation, first = initial_follow_up
      first.follow_up_attempt.update!(admission_state: state, admitted_at: state.in?(%w[admitted accepted unknown]) ? Time.current : nil)
      r09_update_offer(offer, name: 'A revision is not another attempt')

      expect(schedule(conversation)).to be_nil
      expect(LeadFollowUp.where(follow_up_attempt_id: first.follow_up_attempt_id).pluck(:id)).to eq([first.id])
    end
  end

  it 'does not replace a follow-up canceled for control even when its context later changes' do
    offer, conversation, first = initial_follow_up
    first.cancel!('incompatible_control_state')
    r09_update_offer(offer, name: 'Changed after cancellation')

    expect(schedule(conversation)).to be_nil
    expect(first.reload).to be_cancelled
    expect(first.follow_up_attempt).to be_blocked
  end

  it 'rejects content or context edits to an existing artifact' do
    _offer, _conversation, first = initial_follow_up
    expect { first.update!(content: 'A different question') }.to raise_error(ActiveRecord::RecordInvalid)
    first.reload
    expect { first.update!(qualification_context: {}) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  %w[follow_up_opted_out provider_disabled internal_note operator_cancelled no_unanswered_question unexpected].each do |reason|
    it "does not reinterpret #{reason} cancellation as context-only replacement" do
      offer, conversation, first = initial_follow_up
      first.cancel!(reason)
      r09_update_offer(offer, name: 'Fresh context cannot erase cancellation')

      expect(schedule(conversation)).to be_nil
      expect(first.reload.cancellation_reason).to eq(reason)
      expect(first.follow_up_attempt).to be_blocked
    end
  end

  it 'keeps another Offer attempt unchanged when replacing the first Offer context' do
    offer, conversation, first = initial_follow_up
    other_offer = r09_create_offer(r09_configuration(name: 'Independent Offer'))
    other_conversation = r09_conversation(offer: other_offer)
    other = schedule(other_conversation)
    original_other = other.attributes
    r09_update_offer(offer, name: 'First Offer changed')
    successor = schedule(conversation)

    expect(successor.follow_up_attempt_id).to eq(first.follow_up_attempt_id)
    expect(other.reload.attributes).to eq(original_other)
    expect(other.follow_up_attempt.current_follow_up_id).to eq(other.id)
    expect(LeadFollowUpAttempt.where(account: account, contact: r09_lead).count).to eq(2)
  end

  def verify_replacement_link(current, successor)
    expect(successor.id).not_to eq(current.id)
    expect(successor.replaces_follow_up_id).to eq(current.id)
    expect(current.reload.replaced_by_follow_up_id).to eq(successor.id)
    expect(current.superseded_at).to be_present
  end
end
