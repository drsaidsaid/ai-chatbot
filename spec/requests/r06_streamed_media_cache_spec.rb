require 'rails_helper'
require 'net/http'
require 'puma'
require 'timeout'

RSpec.describe 'Protected media HTTP streaming', type: :request do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, assignee: member) }
  let(:attachment) do
    message = create(:message, account: account, conversation: conversation)
    Attachment.create!(account: account, message: message, file_type: :image).tap do |record|
      record.file.attach(io: Rails.root.join('spec/assets/sample.png').open, filename: 'sample.png', content_type: 'image/png')
    end
  end
  let(:server) { Puma::Server.new(Rails.application) }
  let(:http) do
    Net::HTTP.new('127.0.0.1', server.connected_ports.first).tap do |client|
      client.open_timeout = 5
      client.read_timeout = 15
    end
  end

  def authenticated_cookies
    authenticated = http.request(Net::HTTP::Get.new(
                                   "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}", member.create_new_auth_token
                                 ))
    expect(authenticated.code).to eq('200')
    authenticated.get_fields('set-cookie').map { |value| value.split(';', 2).first }.join('; ')
  end

  around do |example|
    # Rails test_case disables Live threads. These committed fixtures let the
    # real Puma response retain normal threaded streaming for this group only.
    test_thread_method = ActionController::Live.instance_method(:new_controller_thread)
    ActionController::Live.define_method(:new_controller_thread) do |&work|
      Thread.new do
        Thread.current.abort_on_exception = true
        work.call
      end
    end
    ActionController::Live.send(:private, :new_controller_thread)
    example.run
  ensure
    ActionController::Live.define_method(:new_controller_thread, test_thread_method)
    ActionController::Live.send(:private, :new_controller_thread)
  end

  before do
    clean_committed_fixtures
    attachment
    server.add_tcp_listener('127.0.0.1', 0)
    server.run
  end

  after do
    server.stop(true)
    clean_committed_fixtures
  end

  # Streaming commits headers before controller after-actions. A real HTTP
  # client must observe this contract; the integration response object is too late.
  %i[file_url thumb_url].each do |media_url|
    it "sends private no-store headers before streaming #{media_url}" do
      path = URI(attachment.public_send(media_url)).request_uri
      attachment.file.representation(resize_to_fill: [250, nil]).processed if media_url == :thumb_url
      request_cookies = authenticated_cookies
      headers_received = Queue.new
      # Hold the real disk stream open until the HTTP client sees its headers.
      # This prevents fast local reads from hiding the premature public policy.
      allow(attachment.file.blob.service).to receive(:download).and_wrap_original do |original, *arguments, &download|
        if download
          original.call(*arguments) do |chunk|
            download.call(chunk)
            Timeout.timeout(15) { headers_received.pop }
          end
        else
          original.call(*arguments)
        end
      end

      result = streamed_get(path, request_cookies) { headers_received << true }

      expect(result[:status]).to eq('200')
      expect(result[:headers]['cache-control']).to eq('private, no-store')
      expect(result[:body]).to include("\x89PNG".b)
    ensure
      headers_received << true if headers_received
    end
  end

  it 'rechecks access and avoids caching for conditional and byte-range media requests' do
    paths = [attachment.file_url, attachment.thumb_url].map { |url| URI(url).request_uri }
    request_headers = [
      { 'Range' => 'bytes=0-9' },
      { 'If-None-Match' => '*' },
      { 'If-Modified-Since' => 1.day.from_now.httpdate }
    ]
    request_cookies = authenticated_cookies

    paths.product(request_headers).each do |path, extra_headers|
      result = http.request(Net::HTTP::Get.new(path, extra_headers.merge('Cookie' => request_cookies)))
      expect(result.code).to eq(extra_headers.key?('Range') && path == paths.first ? '206' : '200')
      expect(result['cache-control']).to eq('private, no-store')
    end

    conversation.update!(assignee: nil)
    paths.product(request_headers + [{}]).each do |path, extra_headers|
      result = http.request(Net::HTTP::Get.new(path, extra_headers.merge('Cookie' => request_cookies)))
      expect(result.code).to eq('403')
      expect(result['cache-control']).to eq('private, no-store')
      expect(result.body).to be_empty
    end
  end

  def streamed_get(path, request_cookies)
    Socket.tcp('127.0.0.1', server.connected_ports.first, connect_timeout: 5) do |socket|
      Timeout.timeout(15) do
        socket.write("GET #{path} HTTP/1.1\r\nHost: 127.0.0.1\r\nCookie: #{request_cookies}\r\nConnection: close\r\n\r\n")
        status = socket.gets("\r\n").split[1]
        response_headers = {}
        while (line = socket.gets("\r\n")) != "\r\n"
          name, value = line.split(':', 2)
          response_headers[name.downcase] = value.strip
        end
        yield
        { status: status, headers: response_headers, body: socket.read }
      end
    end
  end

  def clean_committed_fixtures
    database_name = ActiveRecord::Base.connection_db_config.database
    raise 'Disposable spec database required' unless Rails.env.test? && database_name.end_with?('_spec', '_test')

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
