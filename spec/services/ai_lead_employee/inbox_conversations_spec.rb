require 'rails_helper'

RSpec.describe AiLeadEmployee::InboxConversations do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:inbox) { create(:inbox, account: account, enable_email_collect: false) }
  let(:contact) { create(:contact, account: account) }

  def conversation
    create(:conversation, account: account, inbox: inbox, contact: contact)
  end

  def message_for(record, **attributes)
    create(:message, account: account, inbox: inbox, conversation: record, sender: contact, **attributes)
  end

  def fetch_rows
    described_class.new(scope: account.conversations, user: admin, filters: {}).perform[:conversations]
  end

  def fetch_with_query_count
    queries = []
    message_records = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] if payload[:sql].match?(/\ASELECT.*FROM "messages"/m)
    end
    records_subscriber = ActiveSupport::Notifications.subscribe('instantiation.active_record') do |_name, _start, _finish, _id, payload|
      message_records += payload[:record_count] if payload[:class_name] == 'Message'
    end
    rows = ActiveRecord::Base.uncached { fetch_rows }
    [rows, queries.size, message_records]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    ActiveSupport::Notifications.unsubscribe(records_subscriber) if records_subscriber
  end

  it 'selects the latest public non-activity preview by timestamp, then ID, without private or activity tails' do
    record = conversation
    timestamp = 5.minutes.ago
    message_for(record, content: 'Same timestamp, earlier ID', created_at: timestamp)
    message_for(record, content: 'Latest eligible preview', message_type: :template, created_at: timestamp)
    message_for(record, content: 'Older timestamp, later ID', created_at: 1.day.ago)
    message_for(record, content: 'Private tail', private: true, created_at: 2.minutes.ago)
    message_for(record, content: 'Activity tail', message_type: :activity, created_at: 1.minute.ago)
    no_public = conversation
    message_for(no_public, content: 'Private only', private: true)
    message_for(no_public, content: 'Activity only', message_type: :activity)
    empty = conversation

    previews = fetch_rows.index_by { |row| row[:conversation_id] }

    expect(previews.fetch(record.id)[:last_message_preview]).to eq('Latest eligible preview')
    expect(previews.fetch(no_public.id)[:last_message_preview]).to be_nil
    expect(previews.fetch(empty.id)[:last_message_preview]).to be_nil
  end

  it 'uses one preview query for one or 25 rows without loading all message histories' do
    message_for(conversation, content: 'First preview')
    single_rows, single_count, single_records = fetch_with_query_count
    24.times do |index|
      record = conversation
      message_for(record, content: "Old #{index}", created_at: 1.day.ago)
      message_for(record, content: "Preview #{index}", created_at: 1.hour.ago)
      message_for(record, content: "Private #{index}", private: true)
    end

    page_rows, page_count, page_records = fetch_with_query_count

    expect(single_rows.size).to eq(1)
    expect(page_rows.size).to eq(25)
    expect(page_count).to eq(single_count)
    expect(page_count).to eq(1)
    expect(single_records).to be <= single_rows.size
    expect(page_records).to be <= page_rows.size
    expect(page_rows.pluck(:last_message_preview)).to contain_exactly('First preview', *Array.new(24) { |index| "Preview #{index}" })
  end
end
