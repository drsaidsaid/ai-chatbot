# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offer qualification through the public API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { admin.create_new_auth_token }
  let(:offers_url) { "/api/v1/accounts/#{account.id}/qualification_offers" }

  it 'round-trips two independent Offer configurations in human currency units' do
    first = create_offer('Message support', minimum: '500000.00')
    second = create_offer('Sales training', minimum: '200000.00')

    patch "#{offers_url}/#{first.fetch('id')}", headers: headers, params: { offer: first }, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('currency' => 'TZS')
    expect(response.parsed_body.fetch('budget_ranges').first).to include('minimum' => '500000.00', 'maximum' => nil)
    get "#{offers_url}/#{second.fetch('id')}", headers: headers, as: :json
    expect(response.parsed_body.fetch('budget_ranges').first).to include('minimum' => '200000.00')
  end

  it 'keeps an explicitly empty question list empty after saving and reloading' do
    offer = create_offer('Advice', minimum: '200000.00')
    patch "#{offers_url}/#{offer.fetch('id')}", headers: headers,
                                                params: { offer: offer.merge('questions' => []) }, as: :json

    expect(response).to have_http_status(:success)
    get "#{offers_url}/#{offer.fetch('id')}", headers: headers, as: :json
    expect(response.parsed_body.fetch('questions')).to eq([])
  end

  it 'rejects stale configuration edits without overwriting a newer threshold' do
    offer = create_offer('Message support', minimum: '500000.00')
    patch "#{offers_url}/#{offer.fetch('id')}", headers: headers,
                                                params: { offer: offer.merge('name' => 'Updated name') }, as: :json
    expect(response).to have_http_status(:success)

    patch "#{offers_url}/#{offer.fetch('id')}", headers: headers,
                                                params: { offer: offer.merge('name' => 'Stale edit') }, as: :json

    expect(response).to have_http_status(:conflict)
    get "#{offers_url}/#{offer.fetch('id')}", headers: headers, as: :json
    expect(response.parsed_body.fetch('name')).to eq('Updated name')
  end

  it 'requires current administrator membership for configuration writes' do
    member = create(:user, account: account, role: :agent)
    post offers_url, headers: member.create_new_auth_token, params: { offer: offer_attributes('Unauthorized', '1.00') }, as: :json
    expect(response).to have_http_status(:unauthorized)

    foreign_admin = create(:user, account: create(:account), role: :administrator)
    post offers_url, headers: foreign_admin.create_new_auth_token, params: { offer: offer_attributes('Foreign', '1.00') }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'qualifies the selected Offer from incoming evidence without borrowing another Offer budget' do
    first, second, _conversation_a, _conversation_b, message_a, _message_b, intent_a, intent_b, contact = incoming_offer_scenario
    qualification_a = LeadQualification.find_by!(account: account, contact: contact, offer_id: first.fetch('id'))
    qualification_b = LeadQualification.find_by!(account: account, contact: contact, offer_id: second.fetch('id'))

    expect(qualification_a.evidence_snapshot.fetch('budget')).to include(
      'message_id' => message_a.id, 'polarity' => 'positive', 'amount_minor' => 60_000_000, 'currency' => 'TZS'
    )
    expect(qualification_a).to have_attributes(configuration_version: first.fetch('version'), score: 15)
    expect(qualification_b.evidence_snapshot).not_to have_key('budget')
    expect(intent_a.reload.outbound_message.content).to include('What problem should this Offer solve?')
    expect(intent_a.outbound_message.content).not_to include('What can you spend on this Offer?')
    expect(intent_b.reload.outbound_message.content).to include('What can you spend on this Offer?')
  end

  it 'projects the saved Offer revision and canonical incoming evidence through the scoped dashboard API' do
    first, second, conversation_a, _conversation_b, message_a, = incoming_offer_scenario
    contact = conversation_a.contact
    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{contact.id}", headers: headers,
                                                                            params: { offer_id: first.fetch('id') }
    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('offer_id' => first.fetch('id'), 'configuration_version' => first.fetch('version'),
                                            'current_configuration_version' => first.fetch('version'), 'stale_at' => nil, 'score' => 15,
                                            'next_question' => 'What problem should this Offer solve?')
    expect(response.parsed_body.dig('evidence', 'budget')).to include('amount_minor' => 60_000_000, 'message_id' => message_a.id)
    source_path = "/app/accounts/#{account.id}/conversations/#{conversation_a.display_id}?messageId=#{message_a.id}"
    expect(response.parsed_body.fetch('evidence_records')).to include(
      include('offer_id' => first.fetch('id'), 'source_path' => source_path)
    )

    get "/api/v1/accounts/#{account.id}/lead_qualifications/#{contact.id}", headers: headers,
                                                                            params: { offer_id: second.fetch('id') }
    expect(response).to have_http_status(:success)
    expect(response.parsed_body.dig('evidence', 'budget')).to be_nil
    expect(response.parsed_body.fetch('next_question')).to eq('What can you spend on this Offer?')
  end

  def incoming_offer_scenario
    first, second = configured_offer_pair
    conversation_a, conversation_b, contact = selected_conversations(first, second)
    prepare_orchestration
    message_a, intent_a = process_incoming(conversation_a, 'Bajeti yangu ni TZS 600000.')
    message_b, intent_b = process_incoming(conversation_b, 'Hello')
    [first, second, conversation_a, conversation_b, message_a, message_b, intent_a, intent_b, contact]
  end

  def configured_offer_pair
    first = create_offer('Message support', minimum: '500000.00')
    second = create_offer('Sales training', minimum: '900000.00')
    changes = { 'name' => 'Configured message support', 'rules' => [saved_budget_rule], 'score_weights' => { 'budget' => 0 } }
    patch "#{offers_url}/#{first.fetch('id')}", headers: headers,
                                                params: { offer: first.merge(changes) }, as: :json
    expect(response).to have_http_status(:success)
    [response.parsed_body, second]
  end

  def saved_budget_rule
    { 'kind' => 'score_rule', 'field' => 'budget', 'operator' => 'gte',
      'value' => { 'amount' => '500000.00', 'currency' => 'TZS' }, 'score_delta' => 15, 'priority' => 0, 'enabled' => true }
  end

  def selected_conversations(first, second)
    channel = create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    contact = create(:contact, account: account, name: 'Asha', phone_number: '+255700111231')
    conversation_a = create_offer_conversation(channel, contact)
    conversation_b = create_offer_conversation(channel, contact)
    select_offer(conversation_a, first)
    select_offer(conversation_b, second)
    [conversation_a, conversation_b, contact]
  end

  def prepare_orchestration
    create(:ai_provider_connection, account: account)
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later)
    allow(SendReplyJob).to receive(:perform_later)
  end

  def create_offer(name, minimum:)
    post offers_url, headers: headers, params: { offer: offer_attributes(name, minimum) }, as: :json
    expect(response).to have_http_status(:created)
    response.parsed_body
  end

  def offer_attributes(name, minimum)
    {
      name: name, currency: 'TZS', enabled: true,
      questions: [
        { key: 'budget', meaning: 'Purchase budget capacity', answer_type: 'money', prompt: 'What can you spend on this Offer?', position: 0,
          enabled: true, required: true },
        { key: 'problem', meaning: 'Problem to solve', answer_type: 'text', prompt: 'What problem should this Offer solve?', position: 1,
          enabled: true, required: true }
      ],
      budget_ranges: [{ label: 'Sufficient budget', minimum: minimum, maximum: nil, enabled: true, position: 0 }],
      rules: [], score_thresholds: { qualified: 60, highly_qualified: 80 }
    }
  end

  def create_offer_conversation(channel, contact)
    create(:conversation, account: account, inbox: channel.inbox, contact: contact, control_state: :ai_active,
                          control_version: 1, assignee: nil, status: :open)
  end

  def select_offer(conversation, offer)
    patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/qualification_offer",
          headers: headers, params: { offer_id: offer.fetch('id') }, as: :json
    expect(response).to have_http_status(:success)
  end

  def process_incoming(conversation, content)
    message = create(:message, account: account, inbox: conversation.inbox, conversation: conversation, sender: conversation.contact,
                               message_type: :incoming, content: content)
    intent = create(:ai_orchestration_intent, account: account, conversation: conversation, triggering_message: message,
                                              observed_control_version: conversation.reload.control_version)
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    [message, intent]
  end
end
