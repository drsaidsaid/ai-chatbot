# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::KnowledgeApprovalAlertDeliveryService do
  it 'queues one auditable alert for a draft knowledge item and reuses it idempotently' do
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    account = channel.account
    operator = create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700123456' })
    account.update!(settings: { 'ai_lead_employee' => { 'human_operator_id' => operator.id,
                                                        'alert_routes' => { described_class::ALERT_TYPE => [{ 'type' => 'assignee' }] } } })
    item = create(:knowledge_item, account: account, status: :draft, approved_at: nil, metadata: {})
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).and_return(true)
    allow(SendReplyJob).to receive(:perform_later)

    described_class.new(knowledge_item: item).perform
    delivery = item.reload.metadata.fetch('knowledge_approval_alert_deliveries').sole
    message = account.messages.find(delivery.fetch('message_id'))

    expect(delivery).to include('recipient' => '255700123456', 'status' => 'queued')
    expect(message.content).to include('Knowledge approval needed', "/knowledge?knowledge_item_id=#{item.id}")
    expect(Whatsapp::OutboundAlertAuthority.new(message).failure_code).to be_nil
    expect { described_class.new(knowledge_item: item.reload).perform }.not_to change(account.messages, :count)

    message.update!(status: :failed, external_error: 'temporary provider failure')
    current = described_class.new(knowledge_item: item.reload).current_deliveries.sole
    expect(current).to include(recipient: '255700123456', status: 'failed', recoverable: true)
    expect { described_class.new(knowledge_item: item.reload).perform }.not_to change(account.messages, :count)
    expect(SendReplyJob).to have_received(:perform_later).with(message.id).twice
  end

  it 'suppresses a knowledge approval alert outside the WhatsApp customer response window' do
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    account = channel.account
    operator = create(:user, account: account, custom_attributes: { 'whatsapp_alert_phone' => '+255700123456' })
    account.update!(settings: { 'ai_lead_employee' => { 'human_operator_id' => operator.id,
                                                        'alert_routes' => { described_class::ALERT_TYPE => [{ 'type' => 'assignee' }] } } })
    item = create(:knowledge_item, account: account, status: :draft, approved_at: nil, metadata: {})
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).and_return(true)
    allow(SendReplyJob).to receive(:perform_later)
    described_class.new(knowledge_item: item).perform
    alert = account.messages.find(item.reload.metadata.fetch('knowledge_approval_alert_deliveries').sole.fetch('message_id'))
    provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages})

    SendReplyJob.perform_now(alert.id)

    expect(provider_request).not_to have_been_requested
    expect(alert.reload.content_attributes.dig('whatsapp_delivery', 'failure_code')).to eq('message_window_closed')
    expect do
      described_class.new(knowledge_item: item.reload).perform
    end.not_to change(account.messages, :count)
    expect(alert.reload.whatsapp_outbound_delivery).to be_pending
    expect(SendReplyJob).to have_received(:perform_later).with(alert.id).twice
  end
end
