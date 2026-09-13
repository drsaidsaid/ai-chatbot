# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::TemplateSubmissionService do
  self.use_transactional_tests = false

  before do
    skip 'Dedicated R26 database and explicit fixture cleanup opt-in required' unless committed_fixture_database?

    clean_committed_fixtures
  end

  after { clean_committed_fixtures if committed_fixture_database? }

  def committed_fixture_database?
    Rails.env.test? && ENV['R26_COMMITTED_FIXTURES'] == 'yes' &&
      ActiveRecord::Base.connection_db_config.database == 'ai_chatbot_r26_combined_spec'
  end

  def clean_committed_fixtures
    raise 'Dedicated R26 database and explicit fixture cleanup opt-in required' unless committed_fixture_database?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end

  def fixture
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    channel = create(
      :channel_whatsapp, account: account, provider_config: {}, sync_templates: false,
                         validate_provider_config: false
    )
    channel.update_columns(provider: 'whatsapp_cloud', provider_config: { 'business_account_id' => 'waba-r26' }) # rubocop:disable Rails/SkipsModelValidations
    template = WhatsappTemplate.create!(account: account, channel: channel, created_by: admin, name: 'order_update')
    revision = template.revisions.create!(
      account: account, channel: channel, revision_number: 1, language: 'en_US', category: 'UTILITY', body: 'Order ready',
      submission_key: 'submission-r26', content_digest: 'digest', status: :submission_pending,
      submitted_at: Time.current, submitted_by: admin
    )
    [channel, revision]
  end

  def wait_for_database_lock(pid)
    Timeout.timeout(5) do
      loop do
        waiting = ActiveRecord::Base.connection.select_value(
          "SELECT wait_event_type = 'Lock' FROM pg_stat_activity WHERE pid = #{Integer(pid)}"
        )
        break if ActiveModel::Type::Boolean.new.cast(waiting)

        sleep 0.01
      end
    end
  end

  it 'serializes submission status changes behind the channel authority lock' do
    channel, revision = fixture
    request = stub_request(:post, 'https://graph.facebook.com/v22.0/waba-r26/message_templates').to_return(
      status: 200, body: { id: 'meta-serialized' }.to_json, headers: { 'Content-Type' => 'application/json' }
    )
    worker_pid = Queue.new
    worker = nil

    channel.with_lock do
      worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          worker_pid << connection.select_value('SELECT pg_backend_pid()')
          described_class.new(revision: WhatsappTemplateRevision.find(revision.id)).perform
        end
      end
      wait_for_database_lock(worker_pid.pop)
      expect(revision.reload).to be_submission_pending
      expect(request).not_to have_been_requested
    end
    worker.value

    expect(revision.reload).to have_attributes(status: 'submitted', provider_template_id: 'meta-serialized')
    expect(request).to have_been_requested.once
  ensure
    worker&.join
  end

  it 'does not hold the channel authority lock during provider HTTP' do
    channel, revision = fixture
    request_started = Queue.new
    release = Queue.new
    stub_request(:post, 'https://graph.facebook.com/v22.0/waba-r26/message_templates').to_return do
      request_started << true
      release.pop
      { status: 200, body: { id: 'meta-outside-lock' }.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        described_class.new(revision: WhatsappTemplateRevision.find(revision.id)).perform
      end
    end
    Timeout.timeout(5) { request_started.pop }

    Timeout.timeout(2) { Channel::Whatsapp.find(channel.id).with_lock { true } }
    release << true
    worker.value

    expect(revision.reload).to have_attributes(status: 'submitted', provider_template_id: 'meta-outside-lock')
  ensure
    release << true if release
    worker&.join
  end
end
