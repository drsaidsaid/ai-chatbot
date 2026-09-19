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
    allow(SendReplyJob).to receive(:perform_later)

    described_class.new(knowledge_item: item).perform
    delivery = item.reload.metadata.fetch('knowledge_approval_alert_deliveries').sole
    message = account.messages.find(delivery.fetch('message_id'))

    expect(delivery).to include('recipient' => '255700123456', 'status' => 'queued')
    expect(message.content).to include('Knowledge approval needed', "/knowledge/#{item.id}")
    expect(Whatsapp::OutboundAlertAuthority.new(message).failure_code).to be_nil
    expect { described_class.new(knowledge_item: item.reload).perform }.not_to change(account.messages, :count)
  end
end
