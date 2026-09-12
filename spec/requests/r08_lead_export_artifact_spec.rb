# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'R08 Lead export artifact lifecycle', type: :request do
  self.use_transactional_tests = false

  before { clean_database }
  after { clean_database }

  it 'releases the database snapshot before an unconsumed response body and deletes the artifact on abort' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    create(:contact, :with_phone_number, account: account, name: 'Artifact Lead')
    artifact = AiLeadEmployee::LeadExportCsv.new(account_id: account.id, user_id: admin.id, params: {}).build
    path = artifact.path
    app = lambda do |env|
      env[Rack::RACK_TEMPFILES] << artifact
      [200, { 'content-type' => 'text/csv' }, ActionDispatch::Response::FileBody.new(path)]
    end
    stack = Rack::ETag.new(Rack::TempfileReaper.new(app))

    status, headers, body = stack.call({})

    expect(status).to eq(200)
    expect(headers).not_to have_key('etag')
    expect(body).not_to respond_to(:to_ary)
    expect(ActiveRecord::Base.connection.transaction_open?).to be(false)
    expect(File).to exist(path)
    body.close
    expect(File).not_to exist(path)
  end

  private

  def clean_database
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
