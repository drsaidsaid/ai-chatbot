abort 'Disposable test databases only' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'ale_release_r06_browser'
load Rails.root.join('script/release/seed_synthetic.rb')
account = Account.find_by!(name: 'R01 Synthetic Business')
account.update!(name: 'R06 Synthetic Business')
password = ENV.fetch('RELEASE_ADMIN_PASSWORD')
colleague = User.new(name: 'Musa Colleague', email: 'r06-colleague@example.test', password: password)
colleague.skip_confirmation!
colleague.save!
AccountUser.create!(account: account, user: colleague, role: :agent)
inbox = account.inboxes.first
InboxMember.create!(inbox: inbox, user: colleague)
lead = account.contacts.first
lead.update!(name: 'Asha Synthetic Lead')
first = lead.conversations.first
first.update!(assignee: nil)
message = first.messages.create!(account: account, inbox: inbox, sender: lead, message_type: :incoming,
                                 content: 'Asha first inquiry: please arrange a demo.')
attachment = Attachment.create!(account: account, message: message, file_type: :file)
attachment.file.attach(io: StringIO.new('R06 assigned Lead attachment proof'), filename: 'r06-assigned.txt', content_type: 'text/plain')
second = Conversation.create!(account: account, inbox: inbox, contact: lead, contact_inbox: first.contact_inbox, assignee: colleague, status: :open,
                              control_state: :ai_paused)
second.messages.create!(account: account, inbox: inbox, sender: lead, message_type: :incoming,
                        content: 'COLLEAGUE ONLY: Asha separate confidential inquiry.')
other = Contact.create!(account: account, name: 'Baraka Colleague Lead', identifier: 'r06-hidden')
ci = ContactInbox.create!(inbox: inbox, contact: other, source_id: 'r06-hidden')
hidden = Conversation.create!(account: account, inbox: inbox, contact: other, contact_inbox: ci, assignee: colleague, status: :open,
                              control_state: :ai_paused)
hidden.messages.create!(account: account, inbox: inbox, sender: other, message_type: :incoming,
                        content: 'COLLEAGUE ONLY: Baraka confidential details.')
other_account = Account.create!(name: 'R06 Second Business', locale: 'en')
AccountUser.create!(account: other_account, user: User.find_by!(email: 'release-operator@example.test'), role: :administrator)
puts({ account_id: account.id, second_account_id: other_account.id, assign_conversation: first.display_id, colleague_conversation: second.display_id,
       hidden_conversation: hidden.display_id }.to_json)
