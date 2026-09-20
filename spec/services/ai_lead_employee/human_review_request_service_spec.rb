# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::HumanReviewRequestService do
  let(:account) { create(:account, settings: { ai_review_alert_recipients: ['255700000001'] }) }
  let(:channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      provider_config: { 'phone_number_id' => 'phone-id', 'api_key' => 'secret' },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, control_state: :ai_active) }
  let(:message) { create(:message, account: account, conversation: conversation, inbox: channel.inbox, content: 'Can you guarantee results?') }

  before do
    allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
    allow(SendReplyJob).to receive(:perform_later)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'creates one open review request and queues a canonical WhatsApp alert message' do
    result = described_class.new(
      conversation: conversation,
      lead_message: message,
      reason: 'no_approved_knowledge'
    ).perform

    expect(result.request).to be_open
    expect(result.request.question).to eq('Can you guarantee results?')
    expect(result.request.alert_recipients).to eq(['255700000001'])
    expect(result.request.alert_deliveries).to contain_exactly(
      include('recipient' => '255700000001', 'status' => 'queued', 'message_id' => be_present)
    )
    alert_message = account.messages.find(result.request.alert_deliveries.first['message_id'])
    expect(alert_message.additional_attributes.dig('ai_lead_employee', 'delivery_boundary')).to eq('outbox')
    expect(alert_message.additional_attributes.dig('ai_lead_employee', 'review_request_id')).to eq(result.request.id)
    expect(alert_message.content).to include('Reason: No approved knowledge', 'Owner: Unassigned')
    expect(SendReplyJob).to have_received(:perform_later).with(alert_message.id).once
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)

    expect do
      described_class.new(
        conversation: conversation,
        lead_message: message,
        reason: 'no_approved_knowledge'
      ).perform
    end.not_to change(HumanReviewRequest, :count)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'can persist the review request without queueing alert delivery for simulations' do
    result = described_class.new(
      conversation: conversation,
      lead_message: message,
      reason: 'sensitive_question',
      enqueue_alerts: false
    ).perform

    expect(result.request).to be_open
    expect(result.request.alert_deliveries).to contain_exactly(
      include('recipient' => '255700000001', 'status' => 'queued', 'message_id' => be_present)
    )
    alert_message = account.messages.find(result.request.alert_deliveries.first['message_id'])
    expect(SendReplyJob).not_to have_received(:perform_later).with(alert_message.id)
    expect(Meta::Whatsapp::TextMessageClient).not_to have_received(:new)
  end

  it 'assigns a configured default owner and routes an urgent review only to the configured Business Account member' do
    owner = create(:user, account: account, role: :agent, custom_attributes: { 'whatsapp_alert_phone' => '+255700000099' })
    account.update!(
      settings: {
        'ai_lead_employee' => {
          'human_operator_id' => owner.id,
          'alert_routes' => { described_class::ALERT_TYPE => [{ 'type' => 'member', 'user_id' => owner.id }] }
        }
      }
    )

    result = described_class.new(conversation: conversation, lead_message: message, reason: 'no_approved_knowledge').perform

    expect(result.request.assigned_user).to eq(owner)
    expect(conversation.reload.assignee).to eq(owner)
    expect(result.request.alert_recipients).to eq(['255700000099'])
    expect(Audited::Audit.where(auditable: result.request).last.audited_changes).to include(
      'ai_lead_employee_action' => 'human_review_assignment',
      'assigned_user_id' => [nil, owner.id]
    )
  end

  it 'recovers assignment and alert delivery when a prior attempt committed only the review row' do
    owner = create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700000099' })
    account.update!(settings: { 'ai_lead_employee' => { 'human_operator_id' => owner.id,
                                                        'alert_routes' => { described_class::ALERT_TYPE => [{ 'type' => 'assignee' }] } } })
    existing = create(:human_review_request, account: account, conversation: conversation, lead_message: message,
                                             reason: :no_approved_knowledge, assigned_user: nil,
                                             alert_recipients: [], alert_deliveries: [])

    result = described_class.new(conversation: conversation, lead_message: message, reason: :no_approved_knowledge).perform

    expect(result.created).to be(false)
    expect(existing.reload.assigned_user).to eq(owner)
    expect(conversation.reload.assignee).to eq(owner)
    expect(existing.alert_deliveries.sole).to include('recipient' => '255700000099', 'status' => 'queued')
  end

  it 'restores the retained default owner when the canonical Conversation assignee was cleared' do
    owner = create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700000099' })
    account.update!(settings: { 'ai_lead_employee' => { 'human_operator_id' => owner.id,
                                                        'alert_routes' => { described_class::ALERT_TYPE => [{ 'type' => 'assignee' }] } } })
    request = described_class.new(conversation: conversation, lead_message: message, reason: :no_approved_knowledge).perform.request
    Conversations::AssignmentService.new(conversation: conversation.reload, assignee_id: nil).perform

    described_class.new(conversation: conversation.reload, lead_message: message, reason: :no_approved_knowledge).perform

    expect(request.reload.assigned_user).to eq(owner)
    expect(conversation.reload.assignee).to eq(owner)
  end

  it 'rolls back a created alert Message when persistence fails and replays without a duplicate' do
    service = described_class.new(conversation: conversation, lead_message: message, reason: :no_approved_knowledge)
    allow(service).to receive(:persist_alert_deliveries!).and_wrap_original do |original, *args|
      original.call(*args)
      raise IOError, 'synthetic crash before commit'
    end

    expect { service.perform }.to raise_error(IOError, 'synthetic crash before commit')

    request = HumanReviewRequest.find_by!(conversation: conversation, lead_message: message, reason: :no_approved_knowledge)
    alerts = account.messages.where("additional_attributes #>> '{ai_lead_employee,review_request_id}' = ?", request.id.to_s)
    expect(request.alert_deliveries).to be_empty
    expect(alerts).to be_empty

    described_class.new(conversation: conversation.reload, lead_message: message, reason: :no_approved_knowledge).perform

    expect(request.reload.alert_deliveries.one?).to be(true)
    expect(alerts.reload.count).to eq(1)
  end

  it 'rejects a queued assignee alert after the conversation is reassigned' do
    owner = create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700000099' })
    replacement = create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700000098' })
    account.update!(settings: { 'ai_lead_employee' => { 'human_operator_id' => owner.id,
                                                        'alert_routes' => { described_class::ALERT_TYPE => [{ 'type' => 'assignee' }] } } })
    request = described_class.new(conversation: conversation, lead_message: message, reason: :no_approved_knowledge).perform.request
    alert = account.messages.find(request.alert_deliveries.sole.fetch('message_id'))

    Conversations::AssignmentService.new(conversation: conversation.reload, assignee_id: replacement.id).perform

    expect(Whatsapp::OutboundAlertAuthority.new(alert.reload).failure_code).to eq('control_changed')
  end

  it 'suppresses a review alert outside the WhatsApp customer response window' do
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).and_return(true)
    request = described_class.new(conversation: conversation, lead_message: message, reason: :no_approved_knowledge).perform.request
    alert = account.messages.find(request.alert_deliveries.sole.fetch('message_id'))
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})

    SendReplyJob.perform_now(alert.id)

    expect(provider_request).not_to have_been_requested
    expect(alert.reload.content_attributes.dig('whatsapp_delivery', 'failure_code')).to eq('message_window_closed')
  end
end
