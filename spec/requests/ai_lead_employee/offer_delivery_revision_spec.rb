# frozen_string_literal: true

require 'rails_helper'

# Source-only preparation; no execution, real-provider call or green claim.
RSpec.describe 'Offer revision at queued delivery boundaries', type: :request do
  include_context 'with Offer qualification requests'

  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  def queued_reply
    offer = r09_create_offer(r09_configuration)
    conversation = r09_conversation(offer: offer)
    incoming, intent = r09_receive(conversation, 'Hello')
    incoming.update!(provider_created_at: Time.current)
    [offer, conversation, intent.outbound_message]
  end

  def stub_delivery_for(message)
    stub_request(:post, provider_url).to_return(status: 200, body: { messages: [{ id: 'wamid.R09.GREETING' }] }.to_json,
                                                headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, provider_url).with { |request| JSON.parse(request.body).dig('text', 'body') == message.content }
                                     .to_return(status: 200, body: { messages: [{ id: 'wamid.R09.QUALIFICATION' }] }.to_json,
                                                headers: { 'Content-Type' => 'application/json' })
  end

  def dispatch_queue
    AiLeadEmployee::OutboxDispatchJob.perform_now
  end

  def sales_handoff_scenario
    offer = r09_create_offer(r09_sales_call_configuration(currency: 'USD'))
    conversation = r09_conversation(offer: offer)
    r09_record_offer_evidence(conversation, offer, 'contact_details', '+255700111231')
    r09_record_offer_evidence(conversation, offer, 'sales_call_agreement', true)
    incoming = create(:message, account: account, inbox: conversation.inbox, conversation: conversation,
                                sender: conversation.contact, message_type: :incoming,
                                content: 'I need more leads now and I am ready to proceed.')
    result = AiLeadEmployee::QualificationService.new(conversation: conversation, incoming_message: incoming).perform
    [offer, conversation, result]
  end

  it 'retains the evaluated Offer and revision in both the actual Message and its queued event' do
    offer, _conversation, message = queued_reply
    context = { 'offer_id' => offer.fetch('id'), 'configuration_version' => offer.fetch('version') }

    expect(message.additional_attributes.dig('ai_lead_employee', 'qualification')).to include(context)
    expect(OutboxEvent.find_by!(aggregate: message).payload.fetch('qualification')).to include(context)
  end

  it 'cancels a recorded qualification reply after its Offer configuration changes' do
    offer, _conversation, message = queued_reply
    request = stub_delivery_for(message)
    r09_update_offer(offer, name: 'Updated before dispatch')
    expect(response).to have_http_status(:success)

    dispatch_queue

    expect(message.reload.whatsapp_outbound_delivery).to be_canceled
    expect(request).not_to have_been_requested
  end

  it 'cancels a recorded qualification reply after the Conversation selects another Offer' do
    _offer, conversation, message = queued_reply
    other = r09_create_offer(r09_configuration(name: 'Other Offer'))
    request = stub_delivery_for(message)
    patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/qualification_offer",
          headers: r09_headers, params: { offer_id: other.fetch('id') }, as: :json
    expect(response).to have_http_status(:success)

    dispatch_queue

    expect(message.reload.whatsapp_outbound_delivery).to be_canceled
    expect(request).not_to have_been_requested
  end

  it 'does not cancel an unchanged Offer reply when a different Offer is edited' do
    _offer, _conversation, message = queued_reply
    other = r09_create_offer(r09_configuration(name: 'Other Offer'))
    request = stub_delivery_for(message)
    r09_update_offer(other, name: 'Other Offer updated')
    expect(response).to have_http_status(:success)

    2.times { dispatch_queue }

    expect(message.reload.whatsapp_outbound_delivery).to be_accepted
    expect(request).to have_been_requested.once
  end

  it 'still cancels an otherwise current Offer reply when provider access is disabled' do
    _offer, _conversation, message = queued_reply
    request = stub_delivery_for(message)
    account.ai_provider_connection.disable!

    dispatch_queue

    expect(message.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'provider_disabled')
    expect(request).not_to have_been_requested
  end

  it 'cancels an old question after a human supplies its answer without changing the Offer configuration' do
    offer, conversation, message = queued_reply
    request = stub_delivery_for(message)
    post(
      "/api/v1/accounts/#{account.id}/lead_qualifications/#{r09_lead.id}/evidence",
      headers: r09_headers,
      params: { offer_id: offer.fetch('id'), conversation_id: conversation.display_id, signal: 'budget', value: 'TZS 600000' },
      as: :json
    )
    expect(response).to have_http_status(:success)
    expect(AiLeadEmployee::Offer.find(offer.fetch('id')).configuration_version).to eq(offer.fetch('version'))

    dispatch_queue

    expect(message.reload.whatsapp_outbound_delivery).to be_canceled
    expect(request).not_to have_been_requested
  end

  it 'does not reuse one follow-up attempt across two Offers for the same Lead' do
    first, first_conversation, = queued_reply
    second = r09_create_offer(r09_configuration(name: 'Other Offer'))
    second_conversation = r09_conversation(offer: second)
    r09_receive(second_conversation, 'Hello')

    attempts = [first_conversation, second_conversation].map do |conversation|
      result = AiLeadEmployee::QualificationService.new(conversation: conversation).perform
      AiLeadEmployee::FollowUpScheduler.new(conversation: conversation, qualification_result: result).perform.first
    end

    expect(attempts.map(&:id).uniq.length).to eq(2)
    expect(attempts.map { |attempt| attempt.reload.lead_qualification.offer_id }).to eq([first.fetch('id'), second.fetch('id')])
  end

  it 'does not prepare a stale follow-up after an Offer edit even if Conversation control is unchanged' do
    offer, conversation, = queued_reply
    result = AiLeadEmployee::QualificationService.new(conversation: conversation).perform
    follow_up = AiLeadEmployee::FollowUpScheduler.new(conversation: conversation, qualification_result: result).perform.first
    follow_up.update!(scheduled_at: 1.minute.ago)
    r09_update_offer(offer, name: 'Changed before scheduled delivery')
    expect(response).to have_http_status(:success)

    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform

    expect(follow_up.reload).to be_cancelled
    expect(follow_up.message_id).to be_nil
  end

  it 'allows an otherwise current qualification to assign the configured sales-call handoff' do
    _offer, conversation, result = sales_handoff_scenario

    handoff = AiLeadEmployee::HighlyQualifiedHandoffService.new(
      conversation: conversation, qualification: result.qualification,
      qualification_context: result.qualification_context, defer_alert_delivery: true
    ).perform

    expect(handoff.handoff).to be_persisted
  end

  it 'does not assign a Human Operator using a qualification invalidated by an Offer edit' do
    offer, conversation, result = sales_handoff_scenario
    r09_update_offer(offer, budget_ranges: [{ label: 'New minimum', minimum: '5000.00', enabled: true, position: 0 }])
    expect(response).to have_http_status(:success)

    handoff = AiLeadEmployee::HighlyQualifiedHandoffService.new(
      conversation: conversation, qualification: result.qualification,
      qualification_context: result.qualification_context, defer_alert_delivery: true
    ).perform

    expect(handoff.handoff).to be_nil
    expect(conversation.reload).to be_ai_active
    expect(conversation.assignee_id).to be_nil
  end
end
