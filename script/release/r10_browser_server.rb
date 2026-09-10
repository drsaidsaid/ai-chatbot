# frozen_string_literal: true

abort 'Disposable R10 browser database only' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'ale_release_r10_browser'

require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
WebMock.stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
       .with do |request|
  JSON.parse(request.body).fetch('max_tokens') == 512
end.to_return(
  status: 402,
  body: { error: { message: 'Synthetic browser fixture: insufficient credits at the configured reply ceiling.' } }.to_json,
  headers: { 'Content-Type' => 'application/json' }
)
ActiveJob::Base.queue_adapter = :test
ActionMailer::Base.delivery_method = :test
ViteRuby.reload_with(mode: 'production', auto_build: false, public_output_dir: 'vite')
Rails.application.routes.default_url_options = { host: '127.0.0.1', port: 3220 }
ActionMailer::Base.default_url_options = { host: '127.0.0.1', port: 3220 }
ActionCable.server.config.cable = { 'adapter' => 'redis', 'url' => ENV.fetch('REDIS_URL'), 'channel_prefix' => 'r10_browser' }
ActionCable.server.config.allowed_request_origins = ['http://127.0.0.1:3220', 'http://localhost:3220']

require 'puma'
server = Puma::Server.new(Rails.application)
server.add_tcp_listener('127.0.0.1', 3220)
server.run.join
