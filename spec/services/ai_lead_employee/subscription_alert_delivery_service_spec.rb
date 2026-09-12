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

  it 'automatically returns a confirmed failed alert delivery to pending without creating another message' do
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
    message.whatsapp_outbound_delivery.update!(state: :failed, failure_code: 'provider_rejected')
    message.update!(status: :failed, external_error: 'Synthetic failure')

    expect { Whatsapp::OutboundRecoveryJob.perform_now }.not_to change(account.messages, :count)

    expect(message.whatsapp_outbound_delivery.reload).to be_pending
    expect(message.reload).to have_attributes(status: 'sent', external_error: nil)
    expect(SendReplyJob).to have_received(:perform_later).with(message.id).twice
  end

  it 'rejects a recipient whose administrator membership was removed after the alert was queued' do
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    account = channel.account
    admin = create(:user, account: account, role: :administrator,
                          custom_attributes: { 'whatsapp_alert_phone' => '+255700123456' })
    subscription = create(:ai_subscription, account: account)
    alert = AiLeadEmployee::AiSubscriptionAlert.create!(
      account: account, ai_subscription: subscription, kind: :allowance_exhausted,
      period_started_at: subscription.period_started_at
    )
    allow(SendReplyJob).to receive(:perform_later)
    described_class.new(alert: alert).perform
    message = account.messages.find(alert.reload.alert_deliveries.sole.fetch('message_id'))
    AccountUser.find_by!(account: account, user: admin).destroy!

    expect(Whatsapp::OutboundAlertAuthority.new(message.reload).failure_code).to eq('alert_recipient_removed')
  end

  it 'does not let terminal canceled alerts starve a newer failed alert retry' do
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
    retryable_message = account.messages.find(alert.reload.alert_deliveries.sole.fetch('message_id'))
    retryable_message.whatsapp_outbound_delivery.update!(state: :failed, failure_code: 'provider_rejected')

    101.times do
      message = create(
        :message, account: account, inbox: channel.inbox, message_type: :outgoing,
                  additional_attributes: { ai_lead_employee: { alert_type: described_class::ALERT_TYPE } }
      )
      message.whatsapp_outbound_delivery.update!(state: :canceled, failure_code: 'alert_recipient_removed')
    end

    Whatsapp::OutboundRecoveryJob.perform_now

    expect(retryable_message.whatsapp_outbound_delivery.reload).to be_pending
    expect(SendReplyJob).to have_received(:perform_later).with(retryable_message.id).twice
  end
end
