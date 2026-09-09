require 'rails_helper'

RSpec.describe 'WhatsApp database recovery', type: :request do
  self.use_transactional_tests = false

  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false,
                              provider_config: { 'app_secret' => 'r03-concurrency-secret' })
  end
  let(:contact) { create(:contact, account: channel.account, phone_number: '+255744444444', name: 'Dotto') }

  before do
    clean_committed_fixtures
    create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255744444444')
  end

  after do
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r03_pause_conversation ON conversations')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r03_pause_conversation()')
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r03_pause_event ON whatsapp_webhook_events')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r03_pause_event()')
    # This group commits fixtures across connections; cleanup is confined to the
    # Rails test database and runs after all worker threads have joined.
    clean_committed_fixtures
  end

  def clean_committed_fixtures
    raise 'Test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end

  def receipt(id, body)
    raw = {
      object: 'whatsapp_business_account', entry: [{ id: channel.provider_config['business_account_id'], changes: [{
        field: 'messages', value: {
          metadata: { phone_number_id: channel.provider_config['phone_number_id'], display_phone_number: channel.phone_number.delete_prefix('+') },
          contacts: [{ wa_id: '255744444444', profile: { name: 'Dotto' } }],
          messages: [{ id: id, from: '255744444444', timestamp: '1789000000', type: 'text', text: { body: body } }]
        }
      }] }]
    }.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'r03-concurrency-secret', raw)}"
    Whatsapp::ReceiptAcceptor.new(raw_body: raw, signature: signature).perform
  end

  it 'serializes concurrent receipts and duplicates into one Conversation with both messages' do
    first = receipt('wamid.CONCURRENT.ONE', 'First question')
    second = receipt('wamid.CONCURRENT.TWO', 'Second question')
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      CREATE FUNCTION r03_pause_conversation() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN PERFORM pg_sleep(0.25); RETURN NEW; END $$;
      CREATE TRIGGER r03_pause_conversation BEFORE INSERT ON conversations
      FOR EACH ROW EXECUTE FUNCTION r03_pause_conversation();
    SQL
    start = Queue.new
    workers = [first.id, second.id, first.id, second.id].map do |id|
      Thread.new do
        start.pop
        ActiveRecord::Base.connection_pool.with_connection { Webhooks::WhatsappEventsJob.perform_now(id) }
      end
    end
    workers.size.times { start << true }
    workers.each(&:value)

    expect(channel.inbox.messages.incoming.pluck(:content)).to contain_exactly('First question', 'Second question')
    expect(channel.inbox.conversations.count).to eq(1)
    expect(Whatsapp::WebhookEvent.processed.count).to eq(2)
  ensure
    workers&.each(&:join)
  end

  it 'recovers a killed worker after message insertion but before normalization commits' do
    saved = receipt('wamid.R03.CRASH', 'Survives a killed worker')
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      CREATE FUNCTION r03_pause_event() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.state = 1 THEN PERFORM pg_sleep(60); END IF; RETURN NEW; END $$;
      CREATE TRIGGER r03_pause_event BEFORE UPDATE ON whatsapp_webhook_events
      FOR EACH ROW EXECUTE FUNCTION r03_pause_event();
    SQL
    Dir.mktmpdir('whatsapp-crash-') do |directory|
      pid_file = File.join(directory, 'database_pid')
      worker_file = File.join(directory, 'worker.rb')
      File.write(worker_file, <<~RUBY)
        raise 'Test only' unless Rails.env.test?
        File.write(#{pid_file.inspect}, ActiveRecord::Base.connection.select_value('SELECT pg_backend_pid()'))
        Webhooks::WhatsappEventsJob.perform_now(#{saved.id})
      RUBY
      worker = Process.spawn(RbConfig.ruby, '-S', 'bundle', 'exec', 'rails', 'runner', worker_file,
                             out: File.join(directory, 'worker.log'), err: [:child, :out])
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
      backend_pid = nil
      loop do
        backend_pid = File.read(pid_file).to_i if File.exist?(pid_file)
        waiting = backend_pid && ActiveRecord::Base.connection.select_value("SELECT wait_event FROM pg_stat_activity WHERE pid = #{backend_pid}")
        break if waiting == 'PgSleep'
        raise 'Worker did not reach the real database crash boundary' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
      Process.kill('KILL', worker)
      Process.wait(worker)
      worker = nil
      # The test trigger is sleeping inside PostgreSQL, which can delay detecting
      # the killed client's closed socket. Terminate only that recorded backend
      # so the deliberately suspended transaction rolls back immediately.
      ActiveRecord::Base.connection.select_value("SELECT pg_terminate_backend(#{backend_pid})")
      ActiveRecord::Base.connection.execute('DROP TRIGGER r03_pause_event ON whatsapp_webhook_events')
      expect(channel.inbox.messages.incoming.count).to eq(0)
      expect(saved.events.reload.first.state).to eq('pending')

      perform_enqueued_jobs(only: Webhooks::WhatsappEventsJob) { Whatsapp::RecoveryJob.perform_now }
      expect(channel.inbox.messages.incoming.pluck(:content)).to eq(['Survives a killed worker'])
      expect(saved.events.reload.first.state).to eq('processed')
    ensure
      if worker
        Process.kill('KILL', worker)
        Process.wait(worker)
      end
    end
  end

  it 'recovers an orchestration intent when its post-commit queue operation fails' do
    admin = create(:user, :administrator, account: channel.account)
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |scenario_key|
      create(:ai_lead_employee_evaluation_run, :reviewed_pass, account: channel.account, user: admin, scenario_key: scenario_key)
    end
    evaluator = AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: channel.account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: 3)
    evaluator.approve!(user: admin, notes: 'Synthetic local test fixtures only')
    adapter_class = Class.new do
      def enqueue(*)
        raise IOError, 'synthetic queue outage after commit'
      end

      alias_method :enqueue_at, :enqueue
    end
    stub_const('UnavailableIntentQueueAdapter', adapter_class)
    adapter = adapter_class.new
    previous_adapter = AiLeadEmployee::OrchestrationIntentJob.queue_adapter
    AiLeadEmployee::OrchestrationIntentJob.queue_adapter = adapter
    saved = receipt('wamid.R03.INTENT', 'Queue recovery')
    Webhooks::WhatsappEventsJob.perform_now(saved.id)

    expect(saved.events.first).to be_processed
    expect(channel.inbox.messages.incoming.pluck(:content)).to eq(['Queue recovery'])
    intent = AiLeadEmployee::OrchestrationIntent.find_by!(triggering_message: channel.inbox.messages.incoming.first)
    expect(intent).to be_pending
    AiLeadEmployee::OrchestrationIntentJob.queue_adapter = previous_adapter
    expect { Whatsapp::RecoveryJob.perform_now }.to have_enqueued_job(AiLeadEmployee::OrchestrationIntentJob).with(intent.id)
    expect(AiLeadEmployee::OrchestrationIntent.count).to eq(1)
  ensure
    AiLeadEmployee::OrchestrationIntentJob.queue_adapter = previous_adapter if previous_adapter
  end
end
