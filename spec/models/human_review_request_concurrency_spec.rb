# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe HumanReviewRequest, :committed_database do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:release_answer) { Queue.new }

  before do
    skip 'requires the explicitly allocated R12 task database' unless task_database_authorized?

    clean_committed_fixtures
  end

  after do
    release_answer << true
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_committed_fixtures if task_database_authorized?
  end

  it 'does not deadlock a knowledge proposal against answer finalization authority' do
    records = scenario
    authority_acquired = Queue.new
    answer, answer_pid = start_worker do
      ApplicationRecord.transaction do
        AiLeadEmployee::KnowledgeAuthorityLock.acquire_for_answer!(records.fetch(:account).id)
        authority_acquired << true
        release_answer.pop
        Conversation.where(id: records.fetch(:conversation).id).lock('FOR NO KEY UPDATE').load
      end
    end
    Timeout.timeout(15) { authority_acquired.pop }

    proposal, proposal_pid = start_worker do
      described_class.find(records.fetch(:review).id).propose_knowledge!(
        proposer: User.find(records.fetch(:operator).id),
        source_kind: 'refund',
        title: 'Refund guidance',
        answer: 'Refund requests are assessed under the published policy.'
      )
    end
    wait_until { !proposal.alive? || blocked_by?(proposal_pid, answer_pid) }
    expect(blocked_by?(proposal_pid, answer_pid)).to be(true)

    release_answer << true
    finish_workers

    expect(answer.value).to be_present
    expect(proposal.value).to be_persisted
    expect(records.fetch(:review).reload.knowledge_item).to eq(proposal.value)
  end

  def scenario
    account = create(:account)
    operator = create(:user, account: account, role: :agent)
    conversation = create(:conversation, account: account, assignee: operator)
    lead_message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                                    message_type: :incoming, content: 'Can I get a refund?')
    review = create(:human_review_request, account: account, conversation: conversation, lead_message: lead_message)
    review.resolve_with!(answer: 'Private operator note', operator: operator, resolution_kind: 'internal_note')
    { account: account, operator: operator, conversation: conversation, review: review }
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
      raise 'Review concurrency worker did not finish' unless worker.join(20)

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

  def task_database_authorized?
    Rails.env.test? && ENV['R12_COMMITTED_FIXTURES'] == 'yes' &&
      ActiveRecord::Base.connection_db_config.database == ENV['R12_CONCURRENCY_DATABASE'] &&
      ENV['R12_CONCURRENCY_DATABASE']&.match?(/\Aale_r12_[a-z0-9_]+_spec\z/)
  end

  def clean_committed_fixtures
    raise 'Dedicated R12 database and explicit fixture cleanup opt-in required' unless task_database_authorized?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
