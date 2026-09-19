# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe AiLeadEmployee::BusinessSetupSource do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:release_worker) { Queue.new }

  before do
    skip 'requires the explicitly opted-in R19 task-owned database' unless cleanup_authorized?

    clean_database
  end

  after do
    release_worker << true
    workers.each { |worker| worker.join(20) || worker.kill.join }
    clean_database if cleanup_authorized?
  end

  it 'serializes setup publication with a concurrent Knowledge review writer without deadlocking' do
    account, admin, offer = business_records
    source = proposed_source(account, admin, offer)
    item = create(:knowledge_item, account: account, status: :draft, approved_at: nil)
    publication_entered = Queue.new
    allow(source).to receive(:publish_offer_configuration!).and_wrap_original do |original|
      publication_entered << true
      release_worker.pop
      original.call
    end

    _publisher, publisher_pid = start_worker do
      source.publish!(expected_source_version: source.version, expected_offer_version: offer.configuration_version, editor: admin)
    end
    Timeout.timeout(15) { publication_entered.pop }
    reviewer, reviewer_pid = start_worker { KnowledgeItem.find(item.id).approve! }
    wait_until { !reviewer.alive? || blocked_by?(reviewer_pid, publisher_pid) }

    expect(blocked_by?(reviewer_pid, publisher_pid)).to be(true)

    release_worker << true
    finish_workers
    expect(source.reload).to be_published
    expect(item.reload).to be_approved
  end

  it 'holds the admitted source, Offer and Knowledge revision stable through the no-send execution' do
    account, admin, offer = business_records
    source = published_source(account, admin, offer)
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false,
                              validate_provider_config: false)
    connection = create(:ai_provider_connection, account: account)
    provider_client = instance_double(AiLeadEmployee::AiProvider::MeteredClient)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-concurrency', model: connection.model, content: 'Inventory coaching helps shops.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )
    allow(SendReplyJob).to receive(:perform_later)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
    runner = AiLeadEmployee::Evaluation::SandboxRunner.new(
      account: account, user: admin, scenario_key: 'business_setup_context', business_setup_source: source,
      question: 'Which shops use inventory coaching?'
    )
    execution_entered = Queue.new
    allow(runner).to receive(:sandbox_context).and_wrap_original do |original|
      execution_entered << true
      release_worker.pop
      original.call
    end

    execution, execution_pid = start_worker { runner.perform }
    Timeout.timeout(15) { execution_entered.pop }
    writer, writer_pid = start_worker do
      current = AiLeadEmployee::Offer.find(offer.id)
      attributes = current.payload.slice(
        'name', 'currency', 'enabled', 'version', 'qualification_mode', 'next_step', 'questions', 'budget_ranges', 'rules',
        'score_weights', 'score_thresholds'
      )
      AiLeadEmployee::OfferConfigurationWriter.new(offer: current, attributes: attributes).perform
    end
    wait_until { !writer.alive? || blocked_by?(writer_pid, execution_pid) }

    expect(blocked_by?(writer_pid, execution_pid)).to be(true)

    release_worker << true
    finish_workers
    expect(execution.value.run).to be_completed
    expect(execution.value.run.configuration_snapshot.dig('business_setup_source', 'published_offer_version')).to eq(
      source.published_offer_version
    )
    expect(offer.reload.configuration_version).to eq(source.published_offer_version + 1)
  end

  it 'locks and rechecks administrator membership through execution while a concurrent revocation waits' do
    account, admin, offer = business_records
    source = published_source(account, admin, offer)
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false,
                              validate_provider_config: false)
    connection = create(:ai_provider_connection, account: account)
    provider_client = instance_double(AiLeadEmployee::AiProvider::MeteredClient)
    allow(AiLeadEmployee::AiProvider::ClientFactory).to receive(:for).and_return(provider_client)
    allow(provider_client).to receive(:complete).and_return(
      AiLeadEmployee::AiProvider::Response.new(
        id: 'r19-membership', model: connection.model, content: 'Inventory coaching helps shops.',
        finish_reason: 'stop', configuration_version: connection.configuration_version
      )
    )
    allow(SendReplyJob).to receive(:perform_later)
    allow(Meta::Whatsapp::TextMessageClient).to receive(:new)
    runner = AiLeadEmployee::Evaluation::SandboxRunner.new(
      account: account, user: admin, scenario_key: 'business_setup_context', business_setup_source: source,
      question: 'Which shops use inventory coaching?'
    )
    execution_entered = Queue.new
    allow(runner).to receive(:sandbox_context).and_wrap_original do |original|
      execution_entered << true
      release_worker.pop
      original.call
    end

    execution, execution_pid = start_worker { runner.perform }
    Timeout.timeout(15) { execution_entered.pop }
    revoker, revoker_pid = start_worker do
      AccountUser.find_by!(account_id: account.id, user_id: admin.id).update!(role: :agent)
    end
    wait_until { !revoker.alive? || blocked_by?(revoker_pid, execution_pid) }

    expect(blocked_by?(revoker_pid, execution_pid)).to be(true)

    release_worker << true
    finish_workers
    expect(execution.value.run).to be_completed
    expect(AccountUser.find_by!(account_id: account.id, user_id: admin.id)).to be_agent

    rejected = AiLeadEmployee::Evaluation::SandboxRunner.new(
      account: account, user: admin, scenario_key: 'business_setup_context', business_setup_source: source,
      question: 'Which shops use inventory coaching?'
    ).perform
    expect(rejected.run).to be_failed
    expect(rejected.run.steps.first).to include('error' => 'Administrator access is required')
  end

  def business_records
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    offer = account.qualification_offers.create!(
      name: 'Inventory coaching', currency: 'TZS', enabled: true,
      configuration: {
        'qualification_mode' => 'not_configured', 'next_step' => { 'kind' => 'answer_only' },
        'questions' => [], 'budget_ranges' => [], 'rules' => [], 'score_weights' => {},
        'score_thresholds' => { 'qualified' => 60, 'highly_qualified' => 80 }
      }
    )
    [account, admin, offer]
  end

  def proposed_source(account, admin, offer)
    source = account.business_setup_sources.new(
      offer: offer, title: 'Inventory setup', source_type: 'document', body: 'Inventory coaching helps shops.'
    )
    source.proposal = AiLeadEmployee::BusinessSetupProposalExtractor.new(
      offer: offer, body: source.body, reviewed_configuration: reviewed_configuration(offer)
    ).perform
    source.initialize_history!(editor: admin)
    source.save!
    source
  end

  def published_source(account, admin, offer)
    source = proposed_source(account, admin, offer)
    source.publish!(expected_source_version: source.version, expected_offer_version: offer.configuration_version, editor: admin)
    source.reload
  end

  def reviewed_configuration(offer)
    offer.payload.slice(
      'name', 'currency', 'enabled', 'version', 'qualification_mode', 'next_step', 'questions', 'budget_ranges', 'rules',
      'score_weights', 'score_thresholds'
    )
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
      raise 'R19 concurrency worker did not finish' unless worker.join(20)

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

  def clean_database
    raise 'Rails test environment required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end

  def cleanup_authorized?
    ENV['R19_CONCURRENCY_ALLOW_TRUNCATE'] == 'true' &&
      ActiveRecord::Base.connection_db_config.database == ENV['R19_CONCURRENCY_DATABASE']
  end
end
