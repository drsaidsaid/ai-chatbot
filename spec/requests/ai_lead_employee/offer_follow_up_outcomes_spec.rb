# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer follow-up canonical delivery outcomes', type: :request do
  include_context 'with Offer qualification requests'

  let(:delivery_records) { {} }
  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  before do
    delivery_records[:offer] = r09_create_offer
    delivery_records[:conversation] = r09_conversation(offer: delivery_records[:offer])
    create(:message, account: account, inbox: delivery_records[:conversation].inbox, conversation: delivery_records[:conversation],
                     message_type: :incoming, sender: delivery_records[:conversation].contact, provider_created_at: Time.current)
    result = AiLeadEmployee::QualificationService.new(conversation: delivery_records[:conversation]).perform
    delivery_records[:follow_up] =
      AiLeadEmployee::FollowUpScheduler.new(conversation: delivery_records[:conversation], qualification_result: result).perform.first
    delivery_records[:follow_up].update!(scheduled_at: 1.minute.ago)
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: delivery_records[:follow_up]).perform
    delivery_records[:message] = delivery_records[:follow_up].reload.message
    delivery_records[:delivery] = delivery_records[:message].whatsapp_outbound_delivery
    delivery_records[:attempt] = delivery_records[:follow_up].follow_up_attempt
  end

  it 'records admission atomically before HTTP and projects provider acceptance onto the original attempt' do
    observed = nil
    request = stub_request(:post, provider_url).to_return do
      observed = [delivery_records[:attempt].reload.admission_state, delivery_records[:attempt].admitted_at,
                  delivery_records[:delivery].reload.state, delivery_records[:delivery].dispatch_started_at]
      { status: 200, body: '{"messages":[{"id":"wamid.R09.FOLLOWUP.ACCEPTED"}]}', headers: { 'Content-Type' => 'application/json' } }
    end
    2.times { SendReplyJob.perform_now(delivery_records[:message].id) }

    expect(observed).to match(['admitted', be_present, 'dispatching', be_present])
    expect(observed[1]).to eq(observed[3])
    expect(delivery_records[:attempt].reload).to be_accepted
    expect(delivery_records[:attempt].admitted_at).to eq(observed[1])
    expect(delivery_records[:follow_up].reload).to be_sent
    expect(request).to have_been_requested.once
  end

  it 'keeps unknown acceptance consumed across retries and Offer revisions' do
    request = stub_request(:post, provider_url).to_timeout
    2.times { SendReplyJob.perform_now(delivery_records[:message].id) }
    r09_update_offer(delivery_records[:offer], name: 'Revision after timeout')
    result = AiLeadEmployee::QualificationService.new(conversation: delivery_records[:conversation]).perform

    expect(AiLeadEmployee::FollowUpScheduler.new(conversation: delivery_records[:conversation], qualification_result: result).perform).to be_empty
    expect(delivery_records[:attempt].reload).to be_unknown
    expect(delivery_records[:attempt].admitted_at).to be_present
    expect(HumanReviewRequest.where(lead_message: delivery_records[:message], reason: :delivery_unknown).count).to eq(1)
    expect(request).to have_been_requested.once
  end

  it 'consumes a definite provider rejection and denies the operator retry endpoint for that attempt' do
    stub_request(:post, provider_url).to_return(status: 400, body: '{"error":{"code":100,"message":"Invalid parameter"}}',
                                                headers: { 'Content-Type' => 'application/json' })
    SendReplyJob.perform_now(delivery_records[:message].id)

    expect(delivery_records[:delivery].reload).to be_failed
    expect(delivery_records[:attempt].reload).to be_failed
    expect(delivery_records[:attempt].admitted_at).to be_present
    expect(delivery_records[:follow_up].reload).to be_failed
    expect(delivery_records[:delivery].retry_for?(r09_admin)).to be(false)
    expect(delivery_records[:delivery].reload).to be_failed
  end

  it 'consumes preparation failure before admission without granting replacement entitlement' do
    expect(delivery_records[:delivery].fail_preparation!).to be(true)
    r09_update_offer(delivery_records[:offer], name: 'Changed after preparation failure')
    result = AiLeadEmployee::QualificationService.new(conversation: delivery_records[:conversation]).perform

    expect(delivery_records[:attempt].reload).to be_failed
    expect(delivery_records[:attempt].admitted_at).to be_nil
    expect(delivery_records[:follow_up].reload).to be_failed
    expect(AiLeadEmployee::FollowUpScheduler.new(conversation: delivery_records[:conversation], qualification_result: result).perform).to be_empty
  end

  it 'makes publication projection-only and repairs accepted domain state through its ordered owner' do
    delivery_records[:delivery].update!(state: :accepted, accepted_at: Time.current, dispatch_started_at: 1.minute.ago)
    delivery_records[:delivery].publish!
    expect(delivery_records[:follow_up].reload).to be_pending
    expect(delivery_records[:attempt].reload).to be_unadmitted

    delivery_records[:delivery].reconcile!

    expect(delivery_records[:follow_up].reload).to be_sent
    expect(delivery_records[:attempt].reload).to be_accepted
    expect(delivery_records[:attempt].admitted_at).to eq(delivery_records[:delivery].dispatch_started_at)
    expect(OutboxEvent.find_by!(aggregate: delivery_records[:message])).to be_delivered
  end

  it 'consumes exhausted abandoned claims without an admission timestamp or replacement' do
    delivery_records[:delivery].update!(state: :claimed, owner_token: 'expired', attempts: 3, lease_expires_at: 1.minute.ago)
    expect(delivery_records[:delivery].recover!).to be(false)

    expect(delivery_records[:delivery].reload).to be_failed
    expect(delivery_records[:attempt].reload).to be_failed
    expect(delivery_records[:attempt].admitted_at).to be_nil
    expect(delivery_records[:follow_up].reload).to be_failed
  end

  it 'recovers an expired dispatch as unknown without returning its attempt to pending' do
    admitted_at = 2.minutes.ago
    delivery_records[:attempt].update!(admission_state: :admitted, admitted_at: admitted_at)
    delivery_records[:delivery].update!(state: :dispatching, dispatch_started_at: admitted_at, lease_expires_at: 1.minute.ago)
    2.times { expect(delivery_records[:delivery].recover!).to be(false) }

    expect(delivery_records[:attempt].reload).to be_unknown
    expect(delivery_records[:attempt].admitted_at).to be_within(0.001).of(admitted_at)
    expect(HumanReviewRequest.where(lead_message: delivery_records[:message], reason: :delivery_unknown).count).to eq(1)
  end

  it 'does not recover or send the predecessor after replacing a claimed never-admitted artifact' do
    delivery_records[:delivery].update!(state: :claimed, owner_token: 'old-owner', lease_expires_at: 1.minute.ago)
    r09_update_offer(delivery_records[:offer], name: 'Changed before admission')
    result = AiLeadEmployee::QualificationService.new(conversation: delivery_records[:conversation]).perform
    successor = AiLeadEmployee::FollowUpScheduler.new(conversation: delivery_records[:conversation], qualification_result: result).perform.first

    expect(successor.replaces_follow_up_id).to eq(delivery_records[:follow_up].id)
    expect(delivery_records[:delivery].reload).to have_attributes(state: 'canceled', owner_token: nil, lease_expires_at: nil)
    expect(delivery_records[:delivery].recover!).to be(false)
    SendReplyJob.perform_now(delivery_records[:message].id)
    expect(successor.reload.message_id).to be_nil
    expect(WebMock).not_to have_requested(:post, provider_url)
  end
end
