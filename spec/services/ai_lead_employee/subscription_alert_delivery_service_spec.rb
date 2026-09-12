# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::SubscriptionAlertDeliveryService do
  it 'queues one durable WhatsApp alert to a configured Business Account owner without consuming AI allowance' do
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    account = channel.account
    create(:user, account: account, role: :administrator,
                  custom_attributes: { 'whatsapp_alert_phone' => '+255700123456' })
    subscription = create(:ai_subscription, account: account)
    alert = AiLeadEmployee::AiSubscriptionAlert.create!(
      account: account, ai_subscription: subscription, kind: :allowance_exhausted,
      period_started_at: subscription.period_started_at
    )
    allow(SendReplyJob).to receive(:perform_later)

    described_class.new(alert: alert).perform

    expect(alert.reload.alert_recipients).to eq(['255700123456'])
    delivery = alert.alert_deliveries.sole
    message = account.messages.find(delivery.fetch('message_id'))
    expect(delivery.fetch('status')).to eq('queued')
    expect(message.content).to include('allowance exhausted')
    expect(message.additional_attributes.dig('ai_lead_employee', 'ai_subscription_alert_id')).to eq(alert.id)
    expect(message.additional_attributes.dig('ai_lead_employee', 'ai_reply_usage_id')).to be_nil
    expect(SendReplyJob).to have_received(:perform_later).with(message.id).once
  end

  it 'reuses the durable message on retry and authorizes the configured recipient' do
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    account = channel.account
    create(:user, account: account, role: :administrator,
                  custom_attributes: { 'whatsapp_alert_phone' => '+255700123456' })
    subscription = create(:ai_subscription, account: account)
    alert = AiLeadEmployee::AiSubscriptionAlert.create!(
      account: account, ai_subscription: subscription, kind: :allowance_exhausted,
      period_started_at: subscription.period_started_at
    )
    allow(SendReplyJob).to receive(:perform_later)
    described_class.new(alert: alert).perform
    message = account.messages.find(alert.reload.alert_deliveries.sole.fetch('message_id'))

    expect { described_class.new(alert: alert.reload).perform }.not_to change(account.messages, :count)
    expect(SendReplyJob).to have_received(:perform_later).with(message.id).twice
    expect(Whatsapp::OutboundAlertAuthority.new(message.reload).failure_code).to be_nil
  end
end
