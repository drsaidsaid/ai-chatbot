# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe AiLeadEmployee::LeadImportService do
  self.use_transactional_tests = false

  before { clean_database }
  after { clean_database }

  it 'allows only one of two competing applies to create the same phone identity' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    csv = "name,phone_number\nRacing Lead,+255713450001\n"
    tokens = Array.new(2) { preview_token(account, admin, csv) }
    barrier = Concurrent::CyclicBarrier.new(2)

    workers = tokens.map do |token|
      worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          barrier.wait
          apply_result(account.id, admin.id, csv, token)
        end
      end
      worker.report_on_exception = false
      worker
    end
    results = workers.map { |worker| Timeout.timeout(12) { worker.value } }

    expect(results.pluck(:status)).to contain_exactly('completed', 'import_file_changed')
    expect(Contact.where(account: account, phone_number: '+255713450001').count).to eq(1)
  ensure
    barrier&.reset
    terminate_workers(workers)
  end

  it 'documents the waiting-writer limitation after import re-resolution' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    csv = "name,phone_number\nImported Lead,+255713450006\n"
    token = preview_token(account, admin, csv)
    importer = described_class.new(
      account: account, user: admin, file: StringIO.new(csv), mode: 'apply', preview_digest: token
    )
    import_locked = Queue.new
    continue_import = Queue.new
    allow(importer).to receive(:apply!).and_wrap_original do |method, preview|
      import_locked << true
      continue_import.pop
      method.call(preview)
    end

    import_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { importer.perform }
    end
    import_worker.report_on_exception = false
    Timeout.timeout(4) { import_locked.pop }

    writer_result = nil
    writer_pid = Queue.new
    writer_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        writer_pid << ActiveRecord::Base.connection.raw_connection.backend_pid
        Contact.create!(account: account, name: 'Direct Writer', phone_number: '+255713450006')
        writer_result = :created
      rescue ActiveRecord::RecordInvalid
        writer_result = :identity_rejected
      end
    end
    writer_worker.report_on_exception = false
    wait_for_contact_lock_wait(Timeout.timeout(4) { writer_pid.pop })
    continue_import << true
    Timeout.timeout(8) do
      import_worker.join
      writer_worker.join
    end

    expect(import_worker.value).to include(status: 'completed')
    expect(writer_result).to eq(:created)
    expect(Contact.where(account: account, phone_number: '+255713450006').count).to eq(2)
  ensure
    continue_import << true if continue_import && import_worker&.alive?
    terminate_workers([import_worker, writer_worker])
  end

  it 'refuses an apply when the competing identity is committed before import re-resolution' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    csv = "name,phone_number\nImported Lead,+255713450008\n"
    token = preview_token(account, admin, csv)
    Contact.create!(account: account, name: 'Committed Writer', phone_number: '+255713450008')

    result = apply_result(account.id, admin.id, csv, token)

    expect(result).to include(status: 'import_file_changed')
    expect(Contact.where(account: account, phone_number: '+255713450008').count).to eq(1)
  end

  it 'times out behind a direct Contact update and leaves that update untouched' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    contact = create(:contact, account: account, name: 'Existing', phone_number: '+255713450002')
    csv = "name,phone_number\nImported Name,+255713450002\n"
    token = preview_token(account, admin, csv)

    result = nil
    worker = nil
    contact.with_lock do
      contact.update!(name: 'Concurrent Edit')
      worker = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          result = apply_result(account.id, admin.id, csv, token)
        end
      end
      worker.report_on_exception = false
      Timeout.timeout(8) { worker.join }
    end

    expect(result).to include(status: 'import_retry_later')
    expect(contact.reload.name).to eq('Concurrent Edit')
  ensure
    terminate_workers([worker])
  end

  it 'rolls back earlier rows when the five-second transaction deadline expires' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    csv = <<~CSV
      name,phone_number
      First Lead,+255713450003
      Slow Lead,+255713450004
    CSV
    token = preview_token(account, admin, csv)
    install_slow_second_insert

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = apply_result(account.id, admin.id, csv, token)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    expect(result).to include(status: 'import_retry_later')
    expect(elapsed).to be < 6.5
    expect(Contact.where(account: account, phone_number: %w[+255713450003 +255713450004])).to be_empty
  ensure
    remove_slow_insert_trigger
  end

  it 'does not report retry-later when a slow after-commit callback follows a durable import' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    csv = "name,phone_number\nCommitted Lead,+255713450007\n"
    token = preview_token(account, admin, csv)
    slow_callback = proc { sleep 1.5 if phone_number == '+255713450007' }
    Contact.set_callback(:commit, :after, slow_callback)
    stub_const("#{described_class}::APPLY_DEADLINE", 1.second)

    result = apply_result(account.id, admin.id, csv, token)

    expect(result).to include(status: 'completed')
    expect(Contact.where(account: account, phone_number: '+255713450007').count).to eq(1)
  ensure
    Contact.skip_callback(:commit, :after, slow_callback) if slow_callback
  end

  it 'preserves historical phone ambiguity while refusing to treat it as an import update' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    now = Time.current
    Contact.insert_all!([ # rubocop:disable Rails/SkipsModelValidations -- fixture recreates permitted historical ambiguity
                          { account_id: account.id, name: 'Legacy One', phone_number: '+255713450005', created_at: now, updated_at: now },
                          { account_id: account.id, name: 'Legacy Two', phone_number: '+255713450005', created_at: now, updated_at: now }
                        ]) # rubocop:enable Rails/SkipsModelValidations
    preview = described_class.new(
      account: account,
      user: admin,
      file: StringIO.new("name,phone_number\nImported,+255713450005\n")
    ).perform

    expect(account.contacts.where(phone_number: '+255713450005').count).to eq(2)
    expect(account.contacts.where(phone_number: '+255713450005').pluck(:name)).to contain_exactly('Legacy One', 'Legacy Two')
    expect(preview[:rows].first).to include(action: 'ambiguous')
    expect(preview[:can_apply]).to be(false)
  end

  private

  def preview_token(account, admin, csv)
    described_class.new(account: account, user: admin, file: StringIO.new(csv)).perform.fetch(:digest)
  end

  def apply_result(account_id, user_id, csv, token)
    described_class.new(
      account: Account.find(account_id), user: User.find(user_id), file: StringIO.new(csv),
      mode: 'apply', preview_digest: token
    ).perform
  rescue described_class::ImportError => e
    { status: e.error_key }
  end

  def install_slow_second_insert
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      CREATE OR REPLACE FUNCTION r08_slow_second_contact() RETURNS trigger AS $$
      BEGIN
        IF NEW.phone_number = '+255713450004' THEN PERFORM pg_sleep(8); END IF;
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      CREATE TRIGGER r08_slow_second_contact BEFORE INSERT ON contacts
      FOR EACH ROW EXECUTE FUNCTION r08_slow_second_contact();
    SQL
  end

  def wait_for_contact_lock_wait(process_id)
    Timeout.timeout(4) do
      loop do
        waiting = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
          SELECT EXISTS (
            SELECT 1 FROM pg_locks
            WHERE pid = #{Integer(process_id)}
              AND relation = 'contacts'::regclass
              AND NOT granted
          )
        SQL
        break if ActiveModel::Type::Boolean.new.cast(waiting)

        sleep 0.01
      end
    end
  end

  def terminate_workers(workers)
    Array(workers).compact.each do |worker|
      worker.kill if worker.alive?
      worker.join(2)
    end
  end

  def remove_slow_insert_trigger
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r08_slow_second_contact ON contacts')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r08_slow_second_contact()')
  end

  def clean_database
    remove_slow_insert_trigger
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
