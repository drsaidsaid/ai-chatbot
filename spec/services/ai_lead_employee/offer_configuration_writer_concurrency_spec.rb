# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

# Offer evaluation and configuration serialization.
RSpec.describe AiLeadEmployee::OfferConfigurationWriter do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:release_writer) { Queue.new }
  let(:scenario) do
    account = create(:account)
    conversation = create(:conversation, account: account)
    offer = described_class.new(offer: account.qualification_offers.new, attributes: configuration).perform
    conversation.update!(offer: offer)
    message = create(:message, account: account, conversation: conversation, inbox: conversation.inbox,
                               sender: conversation.contact, message_type: :incoming, content: 'My budget is TZS 600000.')
    qualification = AiLeadEmployee::QualificationService.new(conversation: conversation, incoming_message: message).perform.qualification
    { offer: offer, conversation: conversation, message: message, qualification: qualification }
  end

  before { clean_committed_fixtures }

  after do
    release_writer << true
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_committed_fixtures
  end

  it 'lets an evaluation finish before a waiting configuration writer invalidates it', :aggregate_failures do
    records = scenario
    writer_waited = false
    # A third connection holds only a Contact row as a scheduling gate. The
    # evaluator and configuration writer each use their own real connection.
    records.fetch(:conversation).contact.with_lock do
      evaluator, evaluator_pid = start_worker { evaluate_current_message }
      wait_until { blocked_by?(evaluator_pid, backend_pid) }
      writer, writer_pid = start_worker { update_threshold }
      wait_until { !writer.alive? || blocked_by?(writer_pid, evaluator_pid) }
      writer_waited = blocked_by?(writer_pid, evaluator_pid)
      expect(evaluator).to be_alive
    end
    finish_workers

    qualification = records.fetch(:qualification).reload
    expect(writer_waited).to be(true)
    expect(records.fetch(:offer).reload.configuration_version).to eq(2)
    expect(qualification.configuration_version).to eq(1)
    expect(qualification.stale_at).to be_present
  end

  it 'reloads the new configuration when the writer wins before evaluation', :aggregate_failures do
    records = scenario
    writer_updated = Queue.new
    _writer, writer_pid = start_worker do
      AiLeadEmployee::Offer.transaction do
        update_threshold
        writer_updated << true
        release_writer.pop
      end
    end
    Timeout.timeout(15) { writer_updated.pop }
    _evaluator, evaluator_pid = start_worker { evaluate_current_message }
    wait_until { blocked_by?(evaluator_pid, writer_pid) }
    release_writer << true
    finish_workers

    qualification = records.fetch(:qualification).reload
    expect(qualification).to have_attributes(configuration_version: 2, quality: 'unqualified', stale_at: nil)
    expect(qualification.evidence_snapshot.fetch('budget')).to include('message_id' => records.fetch(:message).id, 'amount_minor' => 60_000_000)
    expect(records.fetch(:offer).reload.configuration_version).to eq(qualification.configuration_version)
  end

  %i[membership assignment].each do |authority|
    it "denies an Offer selection already waiting on the Conversation lock after #{authority} is revoked" do
      records = scenario
      conversation = records.fetch(:conversation)
      member = create(:user, account: conversation.account, role: :agent)
      conversation.update!(assignee: member)
      headers = member.create_new_auth_token
      replacement = described_class.new(
        offer: conversation.account.qualification_offers.new, attributes: configuration.merge(name: 'Another Offer')
      ).perform
      request_worker = nil

      conversation.with_lock do
        request_worker, request_pid = start_worker { select_offer_request(headers, replacement.id) }
        wait_until { blocked_by?(request_pid, backend_pid) }
        if authority == :membership
          AccountUser.find_by!(account: conversation.account, user: member).destroy!
        else
          conversation.update!(assignee: nil)
        end
      end
      finish_workers

      expect(request_worker.value).to eq(401)
      expect(conversation.reload.offer_id).to eq(records.fetch(:offer).id)
    end
  end

  def configuration
    {
      name: 'Concurrency test Offer', currency: 'TZS', enabled: true,
      questions: [{ key: 'budget', meaning: 'Purchase budget capacity', answer_type: 'money', prompt: 'What is your budget?',
                    position: 0, enabled: true, required: true }],
      budget_ranges: [{ label: 'Supported budget', minimum: '500000.00', maximum: nil, enabled: true, position: 0 }],
      rules: [], score_thresholds: { qualified: 60, highly_qualified: 80 }
    }
  end

  def evaluate_current_message
    conversation = Conversation.find(scenario.fetch(:conversation).id)
    message = Message.find(scenario.fetch(:message).id)
    AiLeadEmployee::QualificationService.new(conversation: conversation, incoming_message: message).perform
  end

  def update_threshold
    offer = AiLeadEmployee::Offer.find(scenario.fetch(:offer).id)
    attributes = offer.payload
    attributes.fetch('budget_ranges').first['minimum'] = '900000.00'
    attributes['rules'] = [{
      'kind' => 'hard_rule', 'field' => 'budget', 'operator' => 'lt',
      'value' => { 'amount' => '900000.00', 'currency' => 'TZS' },
      'forced_outcome' => 'unqualified', 'priority' => 0, 'enabled' => true
    }]
    described_class.new(offer: offer, attributes: attributes).perform
  end

  def select_offer_request(headers, offer_id)
    conversation = scenario.fetch(:conversation)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.patch "/api/v1/accounts/#{conversation.account_id}/conversations/#{conversation.display_id}/qualification_offer",
                  headers: headers, params: { offer_id: offer_id }, as: :json
    session.response.status
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
      raise 'Offer concurrency worker did not finish' unless worker.join(20)

      worker.value
    end
  end

  def backend_pid
    ActiveRecord::Base.connection.raw_connection.backend_pid
  end

  def blocked_by?(waiting_pid, holding_pid)
    ActiveRecord::Base.uncached do
      ActiveRecord::Base.connection.select_value("SELECT #{Integer(holding_pid)} = ANY(pg_blocking_pids(#{Integer(waiting_pid)}))")
    end
  end

  def wait_until
    Timeout.timeout(15) { sleep(0.01) until yield }
  end

  def clean_committed_fixtures
    database_name = ActiveRecord::Base.connection_db_config.database
    raise 'Disposable spec database required' unless Rails.env.test? && database_name.end_with?('_spec', '_test')

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
