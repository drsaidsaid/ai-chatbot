# Only an empty, disposable browser database may use this synthetic fixture.
database = ActiveRecord::Base.connection_db_config.database
abort 'Use the R04 browser test database' unless Rails.env.test? && database == 'ale_release_r04_browser'
abort 'Existing records are never replaced' if Account.exists? || User.exists?
abort 'Use the local fake provider' unless ENV['WHATSAPP_CLOUD_BASE_URL'] == 'http://127.0.0.1:3225'

require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
require 'factory_bot'
FactoryBot.find_definitions unless FactoryBot.factories.registered?(:account)
ActiveJob::Base.queue_adapter = :test
ActionMailer::Base.delivery_method = :test
ConfigLoader.new.process

channel = FactoryBot.create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
account = channel.account
account.update!(name: 'R04 Synthetic Business', locale: 'en')
admin = FactoryBot.create(:user, :administrator, account: account, name: 'Release Operator',
                                                 email: 'r04-operator@example.test', password: ENV.fetch('RELEASE_ADMIN_PASSWORD'))
InboxMember.create!(inbox: channel.inbox, user: admin)
channel.inbox.update!(name: 'R04 local WhatsApp')
conversation = FactoryBot.create(:conversation, account: account, inbox: channel.inbox, control_state: :ai_active, assignee: nil)
conversation.contact.update!(name: 'Amina — synthetic R04 Lead')
FactoryBot.create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: conversation.contact,
                            message_type: :incoming, content: 'Please explain how my messages are delivered.', provider_created_at: Time.current)
FactoryBot.create(:message, :bot_message, account: account, inbox: channel.inbox, conversation: conversation,
                                          message_type: :outgoing, content: 'Canceled: the operator took over before this AI answer could send.')
Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin)

messages = {}
{
  pending: 'Pending: this saved reply is waiting for the delivery worker.',
  failed: 'Failed: the local provider definitely rejected this reply.',
  unknown: 'Unknown: the local provider returned an uncertain outcome. Check the Review Request.',
  accepted: 'Accepted: the local provider acknowledged this reply; delivery and reading are still separate.',
  delivery_failed: 'Delivery failed after acceptance: this reply must not be automatically resent.'
}.each do |key, content|
  message = FactoryBot.create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: admin,
                                        message_type: :outgoing, content: content)
  SendReplyJob.perform_now(message.id) unless key == :pending
  if key == :delivery_failed
    Whatsapp::MessageStatusProjector.new(message: message.reload, status: { status: 'failed', timestamp: Time.current.to_i.to_s }).perform
  end
  messages[key] = message.id
end
puts({ account_id: account.id, conversation_id: conversation.id, conversation_display_id: conversation.display_id,
       login: admin.email, messages: messages, launch_approved: false }.to_json)
