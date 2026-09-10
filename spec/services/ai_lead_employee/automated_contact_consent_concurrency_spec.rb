# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AutomatedContactConsent do
  self.use_transactional_tests = false

  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:conversation) do
    create(:conversation, account: channel.account, inbox: channel.inbox, control_state: :ai_active, assignee: nil)
  end
  let(:incoming) do
    create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                     sender: conversation.contact, message_type: :incoming, provider_created_at: 2.minutes.ago)
  end
  let(:reply) do
    create(:message, :bot_message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                   sender: nil, message_type: :outgoing, content: 'Pending AI reply')
  end
  let(:stop_message) do
    create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                     sender: conversation.contact, message_type: :incoming, content: 'Stop messaging me.',
                     source_id: 'wamid.R05.RACE.STOP', provider_created_at: 1.minute.ago)
  end
  let(:receipt) do
    Whatsapp::WebhookReceipt.create!(
      raw_body: '{"synthetic":"r05-race"}',
      body_digest: SecureRandom.hex(32),
      verified_routes: [channel.id],
      expanded_at: Time.current
    )
  end
  let(:stop_event) do
    Whatsapp::WebhookEvent.create!(
      receipt: receipt,
      account: channel.account,
      inbox: channel.inbox,
      channel: channel,
      event_key: SecureRandom.uuid,
      kind: 'messages',
      provider_message_id: stop_message.source_id,
      provider_created_at: stop_message.provider_created_at,
      payload: { 'synthetic' => 'r05-race' },
      state: :processed,
      processed_at: Time.current
    )
  end
  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  before do
    clean_committed_fixtures
    create(:ai_provider_connection, account: channel.account)
    incoming
    reply
    stop_event
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).and_return(true)
  end

  after { clean_committed_fixtures }

  it 'blocks provider authorization when withdrawal owns the Channel lock first' do
    withdrawal_entered = Queue.new
    release_withdrawal = Queue.new
    consent = described_class.new(message: stop_message, webhook_event: stop_event)
    allow(consent).to receive(:record_withdrawal_event!).and_wrap_original do |original|
      withdrawal_entered << true
      release_withdrawal.pop
      original.call
    end
    request = stub_request(:post, provider_url)

    stop_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        consent.record_inbound!
      end
    end
    Timeout.timeout(10) { withdrawal_entered.pop }
    send_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { SendReplyJob.perform_now(reply.id) }
    end
    Timeout.timeout(10) do
      Thread.pass until reply.whatsapp_outbound_delivery.reload.claimed?
    end
    release_withdrawal << true
    stop_worker.value
    send_worker.value

    expect(reply.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'opted_out')
    expect(request).not_to have_been_requested
  ensure
    release_withdrawal << true if release_withdrawal
    stop_worker&.join
    send_worker&.join
  end

  it 'preserves an authorized provider outcome and blocks every later automated reply' do
    request_entered = Queue.new
    release_request = Queue.new
    request = stub_request(:post, provider_url).to_return do
      request_entered << true
      release_request.pop
      { status: 200, body: '{"messages":[{"id":"wamid.R05.RACE.ACCEPTED"}]}',
        headers: { 'Content-Type' => 'application/json' } }
    end
    send_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { SendReplyJob.perform_now(reply.id) }
    end
    Timeout.timeout(10) { request_entered.pop }

    described_class.record_inbound!(message: stop_message, webhook_event: stop_event)
    release_request << true
    send_worker.value

    conversation.reload
    later_reply = create(:message, :bot_message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                                 sender: nil, message_type: :outgoing, content: 'Later AI reply')
    SendReplyJob.perform_now(later_reply.id)

    expect(reply.reload.whatsapp_outbound_delivery).to be_accepted
    expect(later_reply.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'opted_out')
    expect(request).to have_been_requested.once
  ensure
    release_request << true if release_request
    send_worker&.join
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    quoted = tables.map { |table| ActiveRecord::Base.connection.quote_table_name(table) }.join(', ')
    ActiveRecord::Base.connection.execute("TRUNCATE #{quoted} CASCADE")
    clear_enqueued_jobs
  end
end
