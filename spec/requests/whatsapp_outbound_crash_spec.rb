require 'rails_helper'
require 'socket'

# Processes and sockets must remain available to cleanup when an example aborts.
# rubocop:disable RSpec/InstanceVariable

RSpec.describe 'WhatsApp outgoing process recovery', type: :request do
  self.use_transactional_tests = false

  before do
    clean_committed_fixtures
    @channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    @admin = create(:user, :administrator, account: @channel.account)
    @conversation = create(:conversation, account: @channel.account, inbox: @channel.inbox, assignee: @admin, control_state: :human_active)
    create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                     message_type: :incoming, provider_created_at: Time.current)
    @message = create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                                sender: @admin, message_type: :outgoing, content: 'Synthetic process recovery')
    @requests = []
    @server = TCPServer.new('127.0.0.1', 0)
    @server_thread = Thread.new { serve_provider }
    @previous_provider_url = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', nil)
    ENV['WHATSAPP_CLOUD_BASE_URL'] = "http://127.0.0.1:#{@server.addr[1]}"
    clear_enqueued_jobs
  end

  after do
    stop_worker
    drop_pause_trigger
    @server&.close
    @server_thread&.join
    ENV['WHATSAPP_CLOUD_BASE_URL'] = @previous_provider_url
    clean_committed_fixtures
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end

  def serve_provider
    loop do
      socket = @server.accept
      headers = []
      while (line = socket.gets) && line != "\r\n"
        headers << line
      end
      length = headers.find { |header| header.downcase.start_with?('content-length:') }.to_s.split(':').last.to_i
      @requests << JSON.parse(socket.read(length))
      body = { messages: [{ id: 'wamid.PROCESS.ACCEPTED' }] }.to_json
      socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      socket.close
    end
  rescue IOError, Errno::EBADF
    nil
  end

  def pause_worker(phase)
    install_pause_trigger(phase)
    Dir.mktmpdir('r04-outbound-worker-') do |directory|
      pid_file = File.join(directory, 'backend_pid')
      worker_file = File.join(directory, 'worker.rb')
      File.write(worker_file, <<~CODE)
        raise 'Rails test database only' unless Rails.env.test?
        ActiveRecord::Base.connection.execute("SET application_name = 'r04-outbound-crash'")
        File.write(#{pid_file.inspect}, ActiveRecord::Base.connection.select_value('SELECT pg_backend_pid()'))
        SendReplyJob.perform_now(#{@message.id})
      CODE
      log = Rails.root.join('tmp/release-r04/evidence', "#{phase}-worker.log")
      FileUtils.mkdir_p(log.dirname)
      @worker = Process.spawn(RbConfig.ruby, '-S', 'bundle', 'exec', 'rails', 'runner', worker_file, out: log.to_s, err: [:child, :out])
      await_persistence_boundary(pid_file)
      stop_worker
      drop_pause_trigger
    end
  end

  def install_pause_trigger(phase)
    @pause_table = phase == 'before_dispatch' ? 'whatsapp_outbound_deliveries' : 'messages'
    condition = phase == 'before_dispatch' ? "NEW.state = 'dispatching'" : "NEW.source_id = 'wamid.PROCESS.ACCEPTED'"
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      CREATE FUNCTION r04_pause_outbound() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF #{condition} THEN PERFORM pg_sleep(60); END IF; RETURN NEW; END $$;
      CREATE TRIGGER r04_pause_outbound BEFORE UPDATE ON #{@pause_table}
      FOR EACH ROW EXECUTE FUNCTION r04_pause_outbound();
    SQL
  end

  def await_persistence_boundary(pid_file)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 90
    loop do
      @backend_pid = File.read(pid_file).to_i if File.exist?(pid_file)
      waiting = @backend_pid && ActiveRecord::Base.connection.select_value("SELECT wait_event FROM pg_stat_activity WHERE pid = #{@backend_pid}")
      break if waiting == 'PgSleep'
      raise 'Worker did not reach the intended persistence boundary' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def stop_worker
    if @worker
      Process.kill('KILL', @worker)
      Process.wait(@worker)
      @worker = nil
    end
    return unless @backend_pid

    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      SELECT pg_terminate_backend(pid) FROM pg_stat_activity
      WHERE pid = #{@backend_pid} AND application_name = 'r04-outbound-crash'
    SQL
    @backend_pid = nil
  end

  def drop_pause_trigger
    return unless @pause_table

    ActiveRecord::Base.connection.execute("DROP TRIGGER IF EXISTS r04_pause_outbound ON #{@pause_table}")
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r04_pause_outbound()')
    @pause_table = nil
  end

  it 'recovers a killed owner before dispatch authorization and sends the Message once' do
    pause_worker('before_dispatch')
    expect(@requests).to be_empty
    travel 2.minutes do
      perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
      perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
    end
    expect(@message.reload.source_id).to eq('wamid.PROCESS.ACCEPTED')
    expect(@requests.size).to eq(1)
  end

  it 'raises one unknown-outcome review after provider acceptance and a killed local commit without sending again' do
    pause_worker('after_acceptance')
    expect(@requests.size).to eq(1)
    expect(@message.reload.source_id).to be_nil
    travel 2.minutes do
      perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
      perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
      SendReplyJob.perform_now(@message.id)
    end
    expect(@message.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('unknown')
    expect(HumanReviewRequest.where(lead_message: @message, reason: :delivery_unknown).count).to eq(1)
    expect(@requests.size).to eq(1)
  end
end

# rubocop:enable RSpec/InstanceVariable
