require 'rails_helper'
require 'timeout'

RSpec.describe 'Membership restoration concurrent with queued cleanup', type: :request do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:preferences) { {} }
  let(:scenario) do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    member = create(:user, account: account, role: :agent)
    other_account = create(:account)
    create(:account_user, account: other_account, user: member, role: :agent)
    {
      account: account, member: member, other_account: other_account,
      conversation: create(:conversation, account: account, assignee: member),
      other_conversation: create(:conversation, account: other_account, assignee: member),
      admin_headers: admin.create_new_auth_token,
      member_headers: member.create_new_auth_token
    }
  end

  before { clean_committed_fixtures }

  after do
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_committed_fixtures
  end

  it 'finishes cleanup before restoration when cleanup acquires the Account first' do
    prepare_revocation
    invitation = nil
    # A real row lock holds cleanup at its first DELETE. The invitation must
    # wait behind cleanup's Account lock instead of reporting success too early.
    ActiveRecord::Base.transaction do
      NotificationSetting.lock.find(preferences.fetch(scenario.fetch(:account).id).fetch('id'))
      _cleanup, cleanup_pid = start_worker { perform_cleanup }
      wait_until { blocked_by?(cleanup_pid, backend_pid) }
      invitation, invitation_pid = start_worker { restore_membership }
      wait_until { !invitation.alive? || blocked_by?(invitation_pid, cleanup_pid) }
    end
    finish_workers

    expect(invitation.value).to include(status: 200, member_id: scenario.fetch(:member).id)
    get "/api/v1/accounts/#{scenario.fetch(:account).id}/notification_settings", headers: scenario.fetch(:member_headers)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      'account_id' => scenario.fetch(:account).id, 'user_id' => scenario.fetch(:member).id,
      'selected_email_flags' => ['email_conversation_assignment'],
      'selected_push_flags' => ['push_conversation_assignment']
    )
    get "/api/v1/accounts/#{scenario.fetch(:account).id}/conversations/#{scenario.fetch(:conversation).display_id}",
        headers: scenario.fetch(:member_headers)
    expect(response).to have_http_status(:unauthorized)
    expect_other_account_unchanged
  end

  it 'preserves restored preferences and assignments when invitation waits first for the Account' do
    prepare_revocation
    invitation = nil
    # Hold the Account while the invitation queues for its row lock first.
    # Cleanup must queue behind it instead of acting on uncommitted membership.
    ActiveRecord::Base.transaction do
      Account.lock.find(scenario.fetch(:account).id)
      invitation, invitation_pid = start_worker { restore_membership }
      wait_until { blocked_by?(invitation_pid, backend_pid) }
      cleanup, cleanup_pid = start_worker { perform_cleanup }
      wait_until { !cleanup.alive? || blocked_by?(cleanup_pid, invitation_pid) }
    end
    finish_workers

    expect(invitation.value).to include(status: 200, member_id: scenario.fetch(:member).id)
    get "/api/v1/accounts/#{scenario.fetch(:account).id}/notification_settings", headers: scenario.fetch(:member_headers)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(preferences.fetch(scenario.fetch(:account).id))
    get "/api/v1/accounts/#{scenario.fetch(:account).id}/conversations/#{scenario.fetch(:conversation).display_id}",
        headers: scenario.fetch(:member_headers)
    expect(response).to have_http_status(:ok)
    expect_other_account_unchanged
  end

  def prepare_revocation
    [scenario.fetch(:account), scenario.fetch(:other_account)].each_with_index do |business, index|
      set_preferences(business, index)
    end
    delete "/api/v1/accounts/#{scenario.fetch(:account).id}/agents/#{scenario.fetch(:member).id}",
           headers: scenario.fetch(:admin_headers)
    expect(response).to have_http_status(:ok)
  end

  def set_preferences(business, index)
    patch "/api/v1/accounts/#{business.id}/notification_settings",
          headers: scenario.fetch(:member_headers),
          params: { notification_settings: {
            selected_email_flags: index.zero? ? [] : ['email_conversation_assignment'],
            selected_push_flags: index.zero? ? [] : ['push_conversation_assignment']
          } }, as: :json
    expect(response).to have_http_status(:ok)
    preferences[business.id] = response.parsed_body
  end

  def restore_membership
    member = scenario.fetch(:member)
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post "/api/v1/accounts/#{scenario.fetch(:account).id}/agents",
                 headers: scenario.fetch(:admin_headers),
                 params: { agent: { email: member.email, name: member.name, role: 'agent' } }, as: :json
    { status: session.response.status, member_id: session.response.parsed_body['id'] }
  end

  def perform_cleanup
    Agents::DestroyJob.perform_now(Account.find(scenario.fetch(:account).id), User.find(scenario.fetch(:member).id))
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
      raise 'Membership worker did not finish' unless worker.join(20)

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

  def expect_other_account_unchanged
    account = scenario.fetch(:other_account)
    conversation = scenario.fetch(:other_conversation)
    headers = scenario.fetch(:member_headers)
    expect_preferences_unchanged(account, headers)
    get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", headers: headers
    expect(response).to have_http_status(:ok)
  end

  def expect_preferences_unchanged(account, headers)
    get "/api/v1/accounts/#{account.id}/notification_settings", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(preferences.fetch(account.id))
  end

  def clean_committed_fixtures
    database_name = ActiveRecord::Base.connection_db_config.database
    raise 'Disposable spec database required' unless Rails.env.test? && database_name.end_with?('_spec', '_test')

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
