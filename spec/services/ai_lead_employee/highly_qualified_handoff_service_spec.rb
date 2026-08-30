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
    allow(SendReplyJob).to receive(:perform_later)
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
  end

  it 'creates one handoff, cancels pending AI replies, assigns the configured operator, and queues routed alerts through the CE sender' do # rubocop:disable RSpec/MultipleExpectations
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
    expect(result.handoff.alert_deliveries).to all(include('status' => 'queued'))
    expect(result.handoff.alert_deliveries).to all(include('message_id', 'conversation_id'))
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
    alert_messages = Message.where(id: result.handoff.alert_deliveries.pluck('message_id'))
    expect(alert_messages.count).to eq(3)
    expect(alert_messages).to all(have_attributes(message_type: 'outgoing', inbox_id: channel.inbox.id))
    expect(alert_messages.pluck(:content).join("\n")).to include(
      "https://inbox.example.test/app/accounts/#{account.id}/conversations/#{conversation.display_id}",
      'Problem: need more leads',
      'Budget signal: $2500',
      'Decision authority: owner'
    )
    result.handoff.alert_deliveries.each do |delivery|
      expect(SendReplyJob).to have_received(:perform_later).with(delivery['message_id'])
    end
  end

  it 'deduplicates retried handoff events and alert routes while retrying failed alert messages' do
    handoff = described_class.new(conversation: conversation, qualification: qualification).perform.handoff
    failed_message = Message.find(handoff.alert_deliveries.first['message_id'])
    failed_message.update!(status: :failed, external_error: 'temporary provider failure')
    allow(SendReplyJob).to receive(:perform_later)

    expect do
      result = described_class.new(conversation: conversation.reload, qualification: qualification).perform
      expect(result.created).to be(false)
    end.not_to change(LeadHandoff, :count)

    handoff.reload
    expect(handoff.alert_deliveries.count).to eq(3)
    expect(handoff.alert_deliveries.pluck('message_id')).to match_array(Message.where(id: handoff.alert_deliveries.pluck('message_id')).ids)
    expect(SendReplyJob).to have_received(:perform_later).with(failed_message.id).twice
    (handoff.alert_deliveries.pluck('message_id') - [failed_message.id]).each do |message_id|
      expect(SendReplyJob).to have_received(:perform_later).with(message_id).once
    end
  end

  it 'adds configured WhatsApp template params with full handoff context to alert messages' do
    channel.update!(
      message_templates: [
        {
          'name' => 'hot_lead_handoff',
          'status' => 'APPROVED',
          'category' => 'UTILITY',
          'language' => 'en',
          'parameter_format' => 'NAMED',
          'components' => [
            {
              'type' => 'BODY',
              'text' => 'Hot lead {{contact}} {{conversation_url}} {{problem}} {{budget}} {{decision_authority}}'
            }
          ]
        }
      ]
    )
    account.update!(
      settings: account.settings.deep_merge(
        'ai_lead_employee' => {
          'alert_templates' => {
            described_class::ALERT_TYPE => {
              'name' => 'hot_lead_handoff',
              'language' => 'en',
              'processed_params' => {}
            }
          }
        }
      )
    )

    handoff = described_class.new(conversation: conversation, qualification: qualification).perform.handoff

    template_params = Message.find(handoff.alert_deliveries.first['message_id']).additional_attributes['template_params']
    expect(template_params).to include('name' => 'hot_lead_handoff', 'language' => 'en')
    expect(template_params.dig('processed_params', 'body')).to include(
      'conversation_url' => "https://inbox.example.test/app/accounts/#{account.id}/conversations/#{conversation.display_id}",
      'problem' => 'need more leads',
      'budget' => '$2500',
      'decision_authority' => 'owner'
    )
  end

  it 'does not retry an existing handoff alert after conversation control is closed' do
    handoff = described_class.new(conversation: conversation, qualification: qualification).perform.handoff
    failed_message = Message.find(handoff.alert_deliveries.first['message_id'])
    failed_message.update!(status: :failed, external_error: 'temporary provider failure')
    conversation.update!(control_state: :closed, status: :resolved)
    expect(SendReplyJob).not_to receive(:perform_later)

    result = described_class.new(conversation: conversation.reload, qualification: qualification).perform

    expect(result.handoff).to be_nil
  end

  it 'does not deliver alerts from the duplicate-create rescue after control changes' do
    create(
      :lead_handoff,
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification,
      assignee: operator,
      alert_type: described_class::ALERT_TYPE,
      alert_recipients: ['255700000001'],
      alert_deliveries: []
    )
    conversation.update!(control_state: :closed, status: :resolved)
    service = described_class.new(conversation: conversation.reload, qualification: qualification)
    allow(service).to receive_messages(
      existing_handoff_record: nil,
      automatic_handoff_allowed?: true,
      find_or_create_handoff!: nil
    )
    allow(service).to receive(:find_or_create_handoff!).and_raise(ActiveRecord::RecordNotUnique)
    expect(SendReplyJob).not_to receive(:perform_later)

    result = service.perform

    expect(result.handoff).to be_nil
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

  it 'does not hand off when Control State no longer permits AI assignment' do
    conversation.update!(control_state: :ai_paused)

    result = described_class.new(conversation: conversation, qualification: qualification).perform

    expect(result.handoff).to be_nil
    expect(conversation.reload.assignee).to be_nil
    expect(LeadHandoff.count).to eq(0)
  end

  it 'rejects cross-tenant qualification records before assignment or alerting' do
    other_account = create(:account)
    other_qualification = create(
      :lead_qualification,
      account: other_account,
      contact: create(:contact, account: other_account),
      quality: :highly_qualified,
      evidence_snapshot: qualification.evidence_snapshot
    )

    result = described_class.new(conversation: conversation, qualification: other_qualification).perform

    expect(result.handoff).to be_nil
    expect(conversation.reload.assignee).to be_nil
    expect(SendReplyJob).not_to have_received(:perform_later)
  end
end
