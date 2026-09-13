# frozen_string_literal: true

abort 'Dedicated R23 browser database only' unless Rails.env.test? &&
                                                   ActiveRecord::Base.connection_db_config.database == 'ale_release_r23_combined'
load Rails.root.join('script/release/seed_synthetic.rb')
account = Account.find_by!(name: 'R01 Synthetic Business')
account.update!(name: 'R23 Combined Billing')
conversation = account.conversations.first!
channel = Channel::Whatsapp.new(account: account, phone_number: '+155500000063', provider: 'whatsapp_cloud')
channel.define_singleton_method(:sync_templates) { nil }
channel.save!(validate: false)
conversation.inbox.update!(channel: channel)
plan = AiLeadEmployee::AiServicePlan.create!(
  code: 'r23-combined', version: 1, name: 'R23 Synthetic', status: :published, currency: 'TZS',
  monthly_price: 250_000, included_ai_replies: 3, top_up_price: 75_000, top_up_ai_replies: 5,
  payment_instructions: 'Synthetic acceptance only. Do not make a payment.', published_at: Time.current
)
AiLeadEmployee::AiSubscription.create!(
  account: account, ai_service_plan: plan, status: :active, reporting_timezone: 'Africa/Dar_es_Salaam',
  period_started_at: Time.current.beginning_of_day, renews_at: 1.month.from_now.beginning_of_day,
  paid_through_at: 1.month.from_now.beginning_of_day, renewal_anchor_day: Time.current.day,
  included_ai_replies: 3, top_up_ai_replies: 0
)
intent = AiLeadEmployee::OrchestrationIntent.create!(
  account: account, conversation: conversation, triggering_message: conversation.messages.first!,
  observed_control_version: conversation.control_version, idempotency_key: 'r23-combined-fixture'
)
usage = AiLeadEmployee::ReplyAllowance.reserve!(intent: intent)
messages = Array.new(2) do |index|
  message = conversation.messages.create!(account: account, inbox: conversation.inbox, message_type: :outgoing,
                                          content: "Synthetic reply part #{index + 1}",
                                          additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
  Whatsapp::OutboundDelivery.create!(account: account, conversation: conversation, message: message,
                                     ai_reply_usage: usage, observed_control_version: conversation.control_version)
  message
end
AiLeadEmployee::ReplyAllowance.register_deliveries!(usage: usage, messages: messages)
messages.first.whatsapp_outbound_delivery.update!(state: :accepted, accepted_at: Time.current, provider_message_id: 'wamid.synthetic.r23')
Whatsapp::MessageStatusProjector.new(message: messages.first, status: { status: 'sent', timestamp: Time.current.to_i.to_s }).perform
messages.last.whatsapp_outbound_delivery.update!(state: :failed, failure_code: 'provider_rejected')
operator = PlatformApp.create!(name: 'R23 Synthetic Finance', finance_operations_enabled: true)
PlatformAppPermissible.create!(platform_app: operator, permissible: account)
puts({ account_id: account.id, usage_id: usage.id, failed_message_id: messages.last.id,
       finance_operator_id: operator.id, summary: AiLeadEmployee::ReplyAllowance.summary(account: account) }.to_json)
