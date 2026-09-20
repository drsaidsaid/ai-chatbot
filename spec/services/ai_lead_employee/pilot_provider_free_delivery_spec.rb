# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Provider-free Pilot delivery authority' do # rubocop:disable RSpec/DescribeClass
  let(:account) { create(:account) }
  let(:provider) { create(:ai_provider_connection, account: account) }
  let(:channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700000001') }
  let(:conversation) do
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, contact_inbox: contact_inbox,
                          control_state: :ai_active, control_version: 3)
  end
  let(:incoming) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                     message_type: :incoming, content: 'Hello', provider_created_at: Time.current)
  end
  let(:authorization) do
    AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: conversation.control_version, provider_configuration_version: provider.configuration_version,
      max_attempts: 1, max_spend_usd: 1, provider_limit_usd: 1,
      external_owner_approval_reference: 'test-owner-approval', provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:test',
                                 verification_digest: 'sha256:response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
  end
  let(:intent) do
    AiLeadEmployee::OrchestrationIntent.find_by(triggering_message: incoming)&.tap do |record|
      record.update!(pilot_authorization: authorization)
    end || create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: incoming,
                                            observed_control_version: conversation.control_version,
                                            pilot_authorization: authorization)
  end
  let(:message) do
    create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: nil,
                     message_type: :outgoing,
                     content: 'Are you asking about this business or one of its Offers?', additional_attributes: {
                       ai_lead_employee: {
                         orchestration_intent_id: intent.id,
                         pilot_authorization_id: authorization.id,
                         outbound_intent_status: 'conversation_reply'
                       }
                     }).tap do |record|
      record.update_columns(sender_type: nil, sender_id: nil) # rubocop:disable Rails/SkipsModelValidations
      intent.update!(outbound_message: record, state: :completed, completed_at: Time.current,
                     decision: { 'status' => 'conversation_reply' })
    end
  end
  let(:delivery) do
    Whatsapp::OutboundDelivery.find_or_create_by!(message: message) do |record|
      record.account = account
      record.conversation = conversation
      record.observed_control_version = conversation.control_version
    end
  end

  it 'admits an exact current provider-free Pilot reply while the general Launch Gate is closed' do
    expect(eligibility_failure).to be_nil
    expect(AiLeadEmployee::AiProviderUsage.where(pilot_authorization: authorization)).to be_empty
    expect(AiLeadEmployee::AiReplyUsage.where(ai_orchestration_intent: intent)).to be_empty
  end

  it 'dispatches an exact current provider-free Pilot reply through the canonical locked authority path' do
    allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response))
    provider_id = Whatsapp::OutboundDispatch.new(
      message: message, channel: channel, recipient: contact_inbox.source_id
    ).perform do |request|
      request.call('https://whatsapp.example.test/messages', body: '{}')
      'wamid.provider-free-pilot'
    end

    expect(provider_id).to eq('wamid.provider-free-pilot')
    expect(delivery.reload).to have_attributes(state: 'accepted', provider_message_id: 'wamid.provider-free-pilot')
    expect(message.reload.source_id).to eq('wamid.provider-free-pilot')
  end

  it 'rejects a forged intent identity even when the message names a current Pilot Authorization' do
    other_incoming = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                                      message_type: :incoming, content: 'Other question')
    forged = AiLeadEmployee::OrchestrationIntent.find_by(triggering_message: other_incoming) ||
             create(:ai_orchestration_intent, account: account, conversation: conversation,
                                              triggering_message: other_incoming,
                                              observed_control_version: conversation.control_version)
    message.update!(additional_attributes: message.additional_attributes.deep_merge(
      'ai_lead_employee' => { 'orchestration_intent_id' => forged.id }
    ))

    expect(eligibility_failure).to eq('pilot_intent_invalid')
  end

  it 'rejects missing intent identity without raising' do
    message.update!(additional_attributes: message.additional_attributes.deep_merge(
      'ai_lead_employee' => { 'orchestration_intent_id' => nil }
    ))

    expect(eligibility_failure).to eq('pilot_intent_invalid')
  end

  it 'admits an exact current provider-free Review Acknowledgment' do
    review = HumanReviewRequest.create!(account: account, conversation: conversation, lead_message: incoming,
                                        reason: :no_approved_knowledge, question: incoming.content)
    intent.update!(review_request: review,
                   decision: { 'acknowledgment' => { 'outbound_message_id' => message.id } })
    message.update!(additional_attributes: message.additional_attributes.deep_merge(
      'ai_lead_employee' => { 'outbound_intent_status' => 'review_acknowledgment' }
    ))

    expect(eligibility_failure).to be_nil
  end

  it 'rejects a revoked provider-free Pilot reply' do
    authorization.update!(status: 'revoked', paused_at: Time.current, pause_reason: 'operator_revoked')

    expect(eligibility_failure).to eq('pilot_authorization_stopped')
  end

  it 'rejects an expired provider-free Pilot reply' do
    authorization.update!(expires_at: 1.second.ago)

    expect(eligibility_failure).to eq('pilot_authorization_expired')
  end

  it 'rejects a provider-free Pilot reply after Conversation control changes' do
    delivery
    conversation.update!(control_version: conversation.control_version + 1)

    expect(eligibility_failure).to eq('control_changed')
  end

  it 'rejects a provider-free Pilot reply after provider configuration changes' do
    delivery
    provider.update!(configuration_version: provider.configuration_version + 1)

    expect(eligibility_failure).to eq('pilot_provider_changed')
  end

  it 'rejects an authorization scoped to another Conversation' do
    other_conversation = create(:conversation, account: account, inbox: channel.inbox, contact: contact,
                                               contact_inbox: contact_inbox, control_state: :ai_active,
                                               control_version: conversation.control_version)
    other_authorization = AiLeadEmployee::PilotAuthorization.create!(
      account: account, inbox: channel.inbox, contact: contact, conversation: other_conversation,
      ai_provider_connection: provider, authorized_by_platform_app: create(:platform_app), recipient: contact_inbox.source_id,
      control_version: other_conversation.control_version, provider_configuration_version: provider.configuration_version,
      max_attempts: 1, max_spend_usd: 1, provider_limit_usd: 1,
      external_owner_approval_reference: 'other-owner-approval', provider_limit_verified_at: Time.current,
      provider_limit_evidence: { kind: 'openrouter_key_limit', key_fingerprint: 'sha256:other',
                                 verification_digest: 'sha256:other-response' },
      starts_at: 1.minute.ago, expires_at: 1.hour.from_now
    )
    message.update!(additional_attributes: message.additional_attributes.deep_merge(
      'ai_lead_employee' => { 'pilot_authorization_id' => other_authorization.id }
    ))

    expect(eligibility_failure(authorization_record: other_authorization)).to eq('pilot_scope_changed')
  end

  it 'rejects a forged provider-free status on a persisted paid intent' do
    message
    intent.update!(decision: { 'status' => 'grounded_answer' })
    message.update!(additional_attributes: message.additional_attributes.deep_merge(
      'ai_lead_employee' => { 'outbound_intent_status' => 'conversation_reply' }
    ))

    expect(eligibility_failure).to eq('pilot_intent_invalid')
  end

  it 'rejects a review acknowledgment whose persisted acknowledgment points elsewhere' do
    message
    review = HumanReviewRequest.create!(account: account, conversation: conversation, lead_message: incoming,
                                        reason: :no_approved_knowledge, question: incoming.content)
    intent.update!(review_request: review,
                   decision: { 'acknowledgment' => { 'outbound_message_id' => message.id + 1 } })
    message.update!(additional_attributes: message.additional_attributes.deep_merge(
      'ai_lead_employee' => { 'outbound_intent_status' => 'review_acknowledgment' }
    ))

    expect(eligibility_failure).to eq('pilot_intent_invalid')
  end

  def eligibility_failure(authorization_record: authorization)
    delivery.reload.conversation.reload
    Whatsapp::OutboundEligibility.new(
      delivery: delivery, channel: channel, recipient: contact_inbox.source_id,
      authority_records: {
        pilot_authorization: authorization_record.reload,
        provider_connection: provider.reload,
        provider_usage: nil,
        orchestration_intent: AiLeadEmployee::OrchestrationIntent.find_by(id: message.additional_attributes.dig(
          'ai_lead_employee', 'orchestration_intent_id'
        ))
      }
    ).failure_code
  end
end
