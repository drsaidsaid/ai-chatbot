# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'R08 Lead export artifact lifecycle', type: :request do
  self.use_transactional_tests = false

  before { clean_database }
  after { clean_database }

  it 'does not expose a sendfile path and deletes the artifact when an offload-selected response aborts' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    create(:contact, :with_phone_number, account: account, name: 'Artifact Lead')
    artifact = AiLeadEmployee::LeadExportCsv.new(account_id: account.id, user_id: admin.id, params: {}).build
    path = artifact.path
    app = lambda do |env|
      env[Rack::RACK_TEMPFILES] << artifact
      env[AiLeadEmployee::LeadExportBodyMiddleware::ENV_KEY] = artifact
      [200, { 'content-type' => 'text/csv' }, ActionDispatch::Response::FileBody.new(path)]
    end
    stack = export_middleware_stack(app)

    status, headers, body = stack.call('sendfile.type' => 'X-Sendfile', 'HTTP_X_SENDFILE_TYPE' => 'X-Sendfile')

    expect(status).to eq(200)
    expect(headers).not_to include('etag', 'x-sendfile')
    expect(body).not_to respond_to(:to_path)
    expect(body).not_to respond_to(:to_ary)
    expect(ActiveRecord::Base.connection.transaction_open?).to be(false)
    expect(File).to exist(path)
    body.close
    expect(File).not_to exist(path)
  end

  it 'deletes the artifact after a normally consumed response' do
    account = create(:account)
    admin = create(:user, account: account, role: :administrator)
    create(:contact, :with_phone_number, account: account, name: 'Consumed Lead')
    artifact = AiLeadEmployee::LeadExportCsv.new(account_id: account.id, user_id: admin.id, params: {}).build
    path = artifact.path
    app = lambda do |env|
      env[Rack::RACK_TEMPFILES] << artifact
      env[AiLeadEmployee::LeadExportBodyMiddleware::ENV_KEY] = artifact
      [200, { 'content-type' => 'text/csv' }, ActionDispatch::Response::FileBody.new(path)]
    end
    stack = export_middleware_stack(app)

    _status, _headers, body = stack.call('sendfile.type' => 'X-Sendfile')
    content = body.each.to_a.join
    body.close

    expect(content).to include('Consumed Lead')
    expect(File).not_to exist(path)
  ensure
    body&.close
  end

  private

  def export_middleware_stack(app)
    replacement = AiLeadEmployee::LeadExportBodyMiddleware.new(app)
    Rack::Sendfile.new(Rack::ETag.new(Rack::TempfileReaper.new(replacement)), 'X-Sendfile')
  end

  def clean_database
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
