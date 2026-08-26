# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::HighlyQualifiedHandoffService do
  let(:account) { create(:account) }
  let(:operator) { create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '255700000001' }) }
  let(:admin) { create(:user, :administrator, account: account, custom_attributes: { 'whatsapp_alert_phone' => '255700000002' }) }
  let!(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      sync_templates: false,
      validate_provider_config: false,
      provider_config: {
        'api_key' => 'test-key',
        'phone_number_id' => '111222333',
        'business_account_id' => '444555666',
        'source' => 'embedded_signup'
      }
    )
  end
  let(:contact) { create(:contact, account: account, name: 'Jane Lead', phone_number: '+255712345678', email: 'jane@example.test') }
  let(:contact_inbox) { create(:contact_inbox, inbox: channel.inbox, contact: contact, source_id: '255712345678') }
  let(:conversation) do
    create(
      :conversation,
      account: account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      assignee: nil,
      assignee_agent_bot: create(:agent_bot, account: account),
      status: :pending,
      control_state: :ai_active,
      control_version: 4,
      waiting_since: nil
    )
  end
  let(:qualification) do
    create(
      :lead_qualification,
      account: account,
      contact: contact,
      quality: :highly_qualified,
      follow_up_state: :human_review,
      score: 90,
      reasons: ['Problem: need more leads', 'Required highly qualified signals are present'],
      evidence_snapshot: {
        'business_type' => { 'value' => 'agency' },
        'problem' => { 'value' => 'need more leads' },
        'lead_volume' => { 'value' => '100 per month' },
        'urgency' => { 'value' => 'urgent' },
        'budget' => { 'value' => '$2500' },
        'decision_authority' => { 'value' => 'owner' },
        'contact_details' => { 'value' => 'jane@example.test' }
      }
    )
  end

  around do |example|
    with_modified_env(FRONTEND_URL: 'https://inbox.example.test', &example)
  end

  before do
    admin
    account.update!(
      settings: {
        'ai_lead_employee' => {
          'human_operator_id' => operator.id,
          'alert_routes' => {
            described_class::ALERT_TYPE => [
              { 'type' => 'assignee' },
              { 'type' => 'admin' },
              { 'type' => 'whatsapp', 'recipient' => '255700000003' }
            ]
          }
        }
      }
    )
    stub_request(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .to_return(
        status: 200,
        body: { messages: [{ id: 'wamid.ALERT' }] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  it 'creates one handoff, cancels pending AI replies, assigns the configured operator, and sends routed alerts' do # rubocop:disable RSpec/MultipleExpectations
    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result.created).to be(true)
    expect(result.assignee).to eq(operator)
    expect(conversation.reload).to have_attributes(
      assignee: operator,
      assignee_agent_bot_id: nil,
      status: 'open',
      control_state: 'human_active',
      control_version: 5
    )
    expect(conversation.waiting_since).to be_present
    expect(result.handoff.alert_recipients).to contain_exactly('255700000001', '255700000002', '255700000003')
    expect(result.handoff.alert_deliveries).to all(include('status' => 'sent'))
    expect(result.handoff.qualification_snapshot).to include(
      'quality' => 'highly_qualified',
      'evidence' => include(
        'business_type' => include('value' => 'agency'),
        'problem' => include('value' => 'need more leads'),
        'lead_volume' => include('value' => '100 per month'),
        'urgency' => include('value' => 'urgent'),
        'budget' => include('value' => '$2500'),
        'decision_authority' => include('value' => 'owner'),
        'contact_details' => include('value' => 'jane@example.test')
      )
    )
    expect(WebMock).to have_requested(:post, 'https://graph.facebook.com/v23.0/123456789/messages').times(3)
    expect(WebMock).to have_requested(:post, 'https://graph.facebook.com/v23.0/123456789/messages')
      .with(body: %r{https://inbox.example.test/app/accounts/#{account.id}/conversations/#{conversation.display_id}})
      .times(3)
  end

  it 'deduplicates retried handoff events and alert routes' do
    described_class.new(conversation: conversation, qualification: qualification).perform

    expect do
      result = described_class.new(conversation: conversation.reload, qualification: qualification).perform
      expect(result.created).to be(false)
    end.not_to change(LeadHandoff, :count)

    expect(WebMock).to have_requested(:post, 'https://graph.facebook.com/v23.0/123456789/messages').times(3)
  end

  it 'does not hand off a qualified lead that is missing urgency evidence' do
    qualification.update!(
      quality: :qualified,
      follow_up_state: :nurture,
      evidence_snapshot: qualification.evidence_snapshot.except('urgency')
    )

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result.handoff).to be_nil
    expect(conversation.reload).to be_ai_active
    expect(LeadHandoff.count).to eq(0)
  end

  it 'does not hand off a highly qualified lead when required evidence is missing' do
    qualification.update!(evidence_snapshot: qualification.evidence_snapshot.except('urgency'))

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result.handoff).to be_nil
    expect(conversation.reload).to be_ai_active
    expect(LeadHandoff.count).to eq(0)
  end
end
