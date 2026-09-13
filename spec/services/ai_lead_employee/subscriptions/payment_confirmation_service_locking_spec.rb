# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe AiLeadEmployee::Subscriptions::PaymentConfirmationService do
  self.use_transactional_tests = false

  before { clean_owned_database }

  after do
    release_table_lock << true if release_table_lock && table_locker&.alive?
    [table_locker, confirmation_worker, summary_worker].compact.each do |worker|
      worker.kill if worker.alive?
      worker.join(2)
    end
    clean_owned_database
  end

  it 'keeps the current subscription locked from payment validation through entitlement mutation' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    operator = create(:platform_app, finance_operations_enabled: true)
    plan = create(:ai_service_plan, code: 'starter', included_ai_replies: 10, monthly_price: 100_000)
    subscription = create(
      :ai_subscription,
      account: account,
      ai_service_plan: plan,
      paid_through_at: Time.zone.parse('2026-11-12T00:00:00Z')
    )
    preview = AiLeadEmployee::Subscriptions::PurchasePreview.new(
      account: account, plan: plan, purpose: :top_up, at: Time.zone.parse('2026-09-20T08:00:00Z')
    ).perform
    request = AiLeadEmployee::Subscriptions::RequestService.new(
      account: account,
      requested_by: admin,
      plan: plan,
      purpose: :top_up,
      preview_signature: AiLeadEmployee::Subscriptions::PurchasePreview.signature_for(account: account, preview: preview)
    ).perform

    blocker_pid = start_table_locker
    confirmation_pid = start_confirmation(account, request, operator)
    wait_until_blocked_by(confirmation_pid, blocker_pid)
    summary_pid = start_summary(account)
    summary_waited = wait_until_blocked_by(summary_pid, confirmation_pid, worker: summary_worker)
    release_table_lock << true

    expect(summary_waited).to be(true)
    expect(Timeout.timeout(10) { confirmation_worker.value }).to be_a(AiLeadEmployee::SubscriptionPaymentConfirmation)
    expect(Timeout.timeout(10) { summary_worker.value }).to include(status: 'active', remaining_ai_replies: 15)
    expect(subscription.reload).to have_attributes(
      period_started_at: Time.zone.parse('2026-10-12T00:00:00Z'),
      renews_at: Time.zone.parse('2026-11-12T00:00:00Z'),
      top_up_ai_replies: 5
    )
    expect(request.reload).to be_confirmed
  end

  private

  attr_reader :table_locker, :confirmation_worker, :summary_worker, :release_table_lock

  def start_table_locker
    ready = Queue.new
    @release_table_lock = Queue.new
    @table_locker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.transaction do
          connection.execute('LOCK TABLE subscription_payment_confirmations IN ACCESS EXCLUSIVE MODE')
          ready << connection.select_value('SELECT pg_backend_pid()').to_i
          release_table_lock.pop
        end
      end
    end
    table_locker.report_on_exception = false
    Timeout.timeout(10) { ready.pop }
  end

  def start_confirmation(account, request, operator)
    ready = Queue.new
    @confirmation_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        ready << connection.select_value('SELECT pg_backend_pid()').to_i
        described_class.new(
          account: Account.find(account.id),
          request: AiLeadEmployee::AiSubscriptionRequest.find(request.id),
          platform_app: PlatformApp.find(operator.id),
          attributes: {
            payment_reference: 'LOCKED-CONFIRMATION', amount: request.quoted_amount,
            currency: request.currency, confirmed_at: '2026-09-12T08:00:00Z', granted_ai_replies: 5
          }
        ).perform
      end
    rescue StandardError => e
      e
    end
    confirmation_worker.report_on_exception = false
    Timeout.timeout(10) { ready.pop }
  end

  def start_summary(account)
    ready = Queue.new
    @summary_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        ready << connection.select_value('SELECT pg_backend_pid()').to_i
        AiLeadEmployee::ReplyAllowance.summary(
          account: Account.find(account.id), at: Time.zone.parse('2026-10-12T00:00:01Z')
        )
      end
    rescue StandardError => e
      e
    end
    summary_worker.report_on_exception = false
    Timeout.timeout(10) { ready.pop }
  end

  def wait_until_blocked_by(waiting_pid, blocking_pid, worker: nil)
    Timeout.timeout(10) do
      loop do
        return false if worker && !worker.alive?
        return true if ActiveModel::Type::Boolean.new.cast(
          ActiveRecord::Base.connection.select_value(
            "SELECT #{Integer(blocking_pid)} = ANY(pg_blocking_pids(#{Integer(waiting_pid)}))"
          )
        )

        sleep 0.01
      end
    end
  end

  def clean_owned_database
    connection = ActiveRecord::Base.connection
    expected = 'ale_r24_6056_20260913_fix_spec'
    unless connection.current_database == expected && ENV['R24_LOCKING_FIXTURES'] == 'yes'
      raise "Payment locking fixtures require #{expected} and explicit opt-in"
    end

    tables = connection.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
