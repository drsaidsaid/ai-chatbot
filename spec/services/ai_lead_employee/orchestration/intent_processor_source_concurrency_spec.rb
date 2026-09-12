# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe AiLeadEmployee::Orchestration::IntentProcessor do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:release_provider) { Queue.new }
  let(:release_final_check) { Queue.new }

  before { clean_committed_fixtures }

  after do
    release_provider << true
    release_final_check << true
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_committed_fixtures
  end

  it 'rejects an answer when the source mutation commits before the final source lock' do
    records = scenario
    provider_entered = Queue.new
    allow(provider_client).to receive(:complete) do
      provider_entered << true
      release_provider.pop
      provider_response(records.fetch(:connection))
    end

    processor, = start_worker { process_intent(records.fetch(:intent).id) }
    Timeout.timeout(15) { provider_entered.pop }
    records.fetch(:item).deactivate!
    release_provider << true
    finish_workers

    expect(processor.value.reload).to have_attributes(state: 'blocked', blocked_reason: 'source_unverified')
  end

  it 'holds the source lock from the final check through outbound commit' do
    records = scenario
    final_check_entered = Queue.new
    processor_service = build_processor(records.fetch(:intent).id)
    allow(provider_client).to receive(:complete).and_return(provider_response(records.fetch(:connection)))
    allow(processor_service).to receive(:sources_still_current?).and_wrap_original do |original|
      current = original.call
      final_check_entered << true
      release_final_check.pop
      current
    end

    processor, processor_pid = start_worker { processor_service.perform }
    Timeout.timeout(15) { final_check_entered.pop }
    writer, writer_pid = start_worker { KnowledgeItem.find(records.fetch(:item).id).deactivate! }
    wait_until { !writer.alive? || blocked_by?(writer_pid, processor_pid) }

    expect(blocked_by?(writer_pid, processor_pid)).to be(true)

    release_final_check << true
    finish_workers

    expect(processor.value.reload).to be_completed
    expect(records.fetch(:item).reload).to be_inactive
  end

  def scenario
    @scenario ||= begin
      channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
      account = channel.account
      contact = create(:contact, account: account, phone_number: '+255700444987')
      contact_inbox = create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700444987')
      conversation = create(:conversation, account: account, inbox: channel.inbox, contact: contact,
                                           contact_inbox: contact_inbox, control_state: :ai_active,
                                           control_version: 2, assignee: nil, status: :open)
      message = create(:message, account: account, inbox: channel.inbox, conversation: conversation, sender: contact,
                                 message_type: :incoming, content: 'Do you integrate with Acme CRM?', source_id: 'wamid.R11.race')
      intent = create(:ai_orchestration_intent, account: account, conversation: conversation,
                                                triggering_message: message, observed_control_version: 2)
      item = create(:knowledge_item, account: account, status: :draft, approved_at: nil,
                                     question: message.content, answer: 'We integrate with Acme CRM.', metadata: {})
      item.approve!
      connection = create(:ai_provider_connection, account: account)
      allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
      { intent: intent, item: item, connection: connection }
    end
  end

  def provider_client
    @provider_client ||= instance_double(AiLeadEmployee::AiProvider::MeteredClient)
  end

  def provider_response(connection)
    AiLeadEmployee::AiProvider::Response.new(
      id: 'r11-source-race', model: connection.model, content: 'We integrate with Acme CRM.',
      finish_reason: 'stop', configuration_version: connection.configuration_version
    )
  end

  def process_intent(intent_id)
    build_processor(intent_id).perform
  end

  def build_processor(intent_id)
    described_class.new(intent: AiLeadEmployee::OrchestrationIntent.find(intent_id), enqueue_deliveries: false,
                        enforce_launch_gate: false)
  end

  def start_worker
    ready = Queue.new
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET lock_timeout = '15s'")
        connection.execute("SET statement_timeout = '20s'")
        ready << connection.raw_connection.backend_pid
        yield
      ensure
        connection.execute('RESET lock_timeout')
        connection.execute('RESET statement_timeout')
      end
    end
    worker.report_on_exception = false
    workers << worker
    [worker, Timeout.timeout(15) { ready.pop }]
  end

  def finish_workers
    workers.each do |worker|
      raise 'Source concurrency worker did not finish' unless worker.join(20)

      worker.value
    end
  end

  def blocked_by?(waiting_pid, holding_pid)
    ActiveRecord::Base.uncached do
      ActiveRecord::Base.connection.select_value(
        "SELECT #{Integer(holding_pid)} = ANY(pg_blocking_pids(#{Integer(waiting_pid)}))"
      )
    end
  end

  def wait_until
    Timeout.timeout(15) { sleep(0.01) until yield }
  end

  def clean_committed_fixtures
    database_name = ActiveRecord::Base.connection_db_config.database
    raise 'Rails test environment required' unless Rails.env.test?

    R11TaskOwnedDatabaseGuard.verify!(
      database_name: database_name,
      allowed_database: ENV.fetch('R11_SOURCE_CONCURRENCY_DATABASE', nil),
      truncate_opt_in: ENV.fetch('R11_SOURCE_CONCURRENCY_ALLOW_TRUNCATE', nil)
    )

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
