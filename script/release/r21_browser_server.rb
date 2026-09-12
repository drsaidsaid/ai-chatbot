# frozen_string_literal: true

abort 'Disposable R21 browser database only' unless Rails.env.test? &&
                                                    ActiveRecord::Base.connection_db_config.database == 'ale_release_r21_browser'

require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
ActiveJob::Base.queue_adapter = :test
ActionMailer::Base.delivery_method = :test
ViteRuby.reload_with(mode: 'production', auto_build: false, public_output_dir: 'vite')
Rails.application.routes.default_url_options = { host: '127.0.0.1', port: 3215 }
ActionMailer::Base.default_url_options = { host: '127.0.0.1', port: 3215 }
ActionCable.server.config.cable = {
  'adapter' => 'redis',
  'url' => ENV.fetch('REDIS_URL'),
  'channel_prefix' => 'r21_browser'
}
ActionCable.server.config.allowed_request_origins = ['http://127.0.0.1:3215', 'http://localhost:3215']

require 'puma'
server = Puma::Server.new(Rails.application)
server.add_tcp_listener('127.0.0.1', 3215)
server.run.join
