# frozen_string_literal: true

# Run with Rails runner only in a disposable test database. No provider settings
# or credentials are created, and the test adapters cannot deliver email/jobs.
database = ActiveRecord::Base.connection_db_config.database
abort 'Use RAILS_ENV=test and an ale_release_* database.' unless Rails.env.test? && database.start_with?('ale_release_')
abort 'Use an empty release database; existing accounts are never replaced.' if Account.exists? || User.exists?
password = ENV.fetch('RELEASE_ADMIN_PASSWORD')

require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
ActiveJob::Base.queue_adapter = :test
ActionMailer::Base.delivery_method = :test

ConfigLoader.new.process
account = Account.create!(name: 'R01 Synthetic Business', locale: 'en')
admin = User.new(name: 'Release Operator', email: 'release-operator@example.test', password: password)
admin.skip_confirmation!
admin.save!
AccountUser.create!(account: account, user: admin, role: :administrator)
channel = Channel::Api.create!(account: account, additional_attributes: {})
inbox = Inbox.create!(account: account, channel: channel, name: 'Synthetic baseline — no provider')
InboxMember.create!(inbox: inbox, user: admin)
contact = Contact.create!(account: account, name: 'Synthetic Lead', identifier: 'r01-synthetic-lead')
contact_inbox = ContactInbox.create!(inbox: inbox, contact: contact, source_id: 'r01-synthetic-lead')
conversation = Conversation.create!(account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                                    status: :open, control_state: :ai_paused)
conversation.messages.create!(account: account, inbox: inbox, sender: contact, message_type: :incoming,
                              content: 'Synthetic release check: I would like to learn about your service.')

puts "Synthetic fixture ready: #{admin.email}; account #{account.id}; conversation #{conversation.display_id}."
puts 'No WhatsApp/AI/calendar connection or launch approval was created.'
