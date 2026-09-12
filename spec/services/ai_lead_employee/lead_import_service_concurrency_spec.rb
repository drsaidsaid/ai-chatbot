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
  end

  it 'times out behind a direct Contact update and leaves that update untouched' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    contact = create(:contact, account: account, name: 'Existing', phone_number: '+255713450002')
    csv = "name,phone_number\nImported Name,+255713450002\n"
    token = preview_token(account, admin, csv)

    result = nil
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
