# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Whatsapp::IncomingMessageBaseService do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:release) { Queue.new }
  let(:tied_timestamp) { Time.zone.parse('2026-09-13 09:00:00 UTC') }

  before do
    skip 'Dedicated R07 current database and explicit fixture cleanup opt-in required' unless committed_fixture_database?

    clean_committed_fixtures
  end

  after do
    4.times { release << true }
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_committed_fixtures if committed_fixture_database?
  end

  it 'records an inflight inbound commit before resume and rejects its delayed recorder', :aggregate_failures do
    records = human_owned_conversation
    inbound_saved = Queue.new
    inbound, inbound_pid = start_worker do
      ActiveRecord::Base.transaction do
        message = persist_inbound_message(records, source_id: 'wamid.RESUME.RACE.INFLIGHT')
        inbound_saved << message.id
        release.pop
      end
    end
    inbound_message_id = Timeout.timeout(15) { inbound_saved.pop }

    resume, resume_pid = start_worker { resume_ai(records.fetch(:conversation_id)) }
    wait_until { blocked_by?(resume_pid, inbound_pid) }
    release << true
    inbound.value
    resume.value

    conversation = Conversation.find(records.fetch(:conversation_id))
    message = Message.find(inbound_message_id)

    expect(conversation.ai_resume_after_message_id).to eq(message.id)
    expect(record_intent(message)).to be_nil
    expect(AiLeadEmployee::OrchestrationIntent.where(triggering_message: message)).to be_empty
  end

  it 'persists the next inbound message after a resume commit and admits it once', :aggregate_failures do
    records = human_owned_conversation
    resumed = Queue.new
    resume, resume_pid = start_worker do
      ActiveRecord::Base.transaction do
        resume_ai(records.fetch(:conversation_id))
        resumed << true
        release.pop
      end
    end
    Timeout.timeout(15) { resumed.pop }

    inbound_saved = Queue.new
    inbound, inbound_pid = start_worker do
      ActiveRecord::Base.transaction do
        message = persist_inbound_message(records, source_id: 'wamid.RESUME.RACE.NEXT')
        inbound_saved << message.id
      end
    end
    wait_until { blocked_by?(inbound_pid, resume_pid) }
    release << true
    resume.value
    inbound.value

    conversation = Conversation.find(records.fetch(:conversation_id))
    message = Message.find(Timeout.timeout(15) { inbound_saved.pop })
    intent = record_intent(message)

    expect(message.id).to be > conversation.ai_resume_after_message_id
    expect(intent).to have_attributes(triggering_message: message, conversation: conversation, state: 'pending')
    expect(record_intent(message)).to eq(intent)
  end

  it 'lets channel-owned ingress wait behind qualification before either path reaches Contact' do
    records = human_owned_conversation
    qualification_has_conversation = Queue.new
    qualification = nil
    ingress = nil

    Contact.find(records.fetch(:contact_id)).with_lock do
      qualification, qualification_pid = start_worker do
        Conversation.find(records.fetch(:conversation_id)).with_lock do
          qualification_has_conversation << true
          Contact.find(records.fetch(:contact_id)).with_lock { true }
        end
      end
      Timeout.timeout(15) { qualification_has_conversation.pop }

      ingress, ingress_pid = start_worker do
        ActiveRecord::Base.transaction do
          Channel::Whatsapp.find(records.fetch(:channel_id)).with_lock do
            persist_inbound_message(records, source_id: 'wamid.LOCK.ORDER', synchronize_identity: true)
          end
        end
      end
      wait_until { blocked_by?(ingress_pid, qualification_pid) }
    end

    qualification.value
    expect(ingress.value).to be_a(Message)
  end

  def human_owned_conversation
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    contact = create(:contact, account: channel.account, phone_number: '+255700111231')
    contact_inbox = create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700111231')
    operator = create(:user, account: channel.account)
    conversation = create(:conversation,
                          account: channel.account,
                          inbox: channel.inbox,
                          contact: contact,
                          contact_inbox: contact_inbox,
                          control_state: :human_active,
                          control_version: 4,
                          assignee: operator)
    { channel_id: channel.id, contact_id: contact.id, conversation_id: conversation.id }
  end

  # rubocop:disable Metrics/MethodLength
  def persist_inbound_message(records, source_id:, synchronize_identity: false)
    channel = Channel::Whatsapp.find(records.fetch(:channel_id))
    conversation = Conversation.find(records.fetch(:conversation_id))
    message = conversation.messages.build(
      account: channel.account,
      inbox: channel.inbox,
      sender: Contact.find(records.fetch(:contact_id)),
      message_type: :incoming,
      status: :sent,
      content: 'A lead message at the shared timestamp.',
      source_id: source_id,
      created_at: tied_timestamp,
      updated_at: tied_timestamp
    )
    service = described_class.new(inbox: channel.inbox, params: {}, outgoing_echo: false)
    service.instance_variable_set(:@conversation, conversation)
    service.instance_variable_set(:@message, message)
    if synchronize_identity
      service.instance_variable_set(:@contact_inbox, conversation.contact_inbox)
      service.instance_variable_set(:@contact, Contact.find(records.fetch(:contact_id)))
      service.instance_variable_set(:@deferred_whatsapp_username, 'lock-order-synthetic')
    end
    service.send(:persist_inbound_message!)
    message
  end
  # rubocop:enable Metrics/MethodLength

  def resume_ai(conversation_id)
    Conversations::ControlService.new(conversation: Conversation.find(conversation_id)).resume_ai!
  end

  def record_intent(message)
    AiLeadEmployee::OrchestrationIntentRecorder.new(message: message, enforce_launch_gate: false, enqueue: false).perform
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

  def blocked_by?(waiting_pid, holding_pid)
    ActiveRecord::Base.uncached do
      ActiveRecord::Base.connection.select_value(
        "SELECT #{Integer(holding_pid)} = ANY(pg_blocking_pids(#{Integer(waiting_pid)}))"
      )
    end
  end

  def wait_until
    Timeout.timeout(15) { sleep 0.01 until yield }
  end

  def committed_fixture_database?
    Rails.env.test? && ENV['ALE_R07_CURRENT_DB'] == '1' &&
      ActiveRecord::Base.connection_db_config.database == 'ale_r07_current_20260913_spec'
  end

  def clean_committed_fixtures
    raise 'Dedicated R07 current database and explicit fixture cleanup opt-in required' unless committed_fixture_database?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
