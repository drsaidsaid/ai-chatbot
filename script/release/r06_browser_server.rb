abort 'Disposable test database only' unless Rails.env.test? && ActiveRecord::Base.connection_db_config.database == 'ale_release_r06_browser'
require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
ActionMailer::Base.delivery_method = :file
ActionMailer::Base.file_settings = { location: Rails.root.join('tmp/release/mail').to_s }
ActionMailer::MailDeliveryJob.queue_adapter = :inline
ActionCableBroadcastJob.queue_adapter = :inline
Rails.application.routes.default_url_options = { host: '127.0.0.1', port: 3216 }
ActionMailer::Base.default_url_options = { host: '127.0.0.1', port: 3216 }
ActionCable.server.config.cable = { 'adapter' => 'redis', 'url' => ENV.fetch('REDIS_URL'), 'channel_prefix' => 'r06_browser' }
ActionCable.server.config.allowed_request_origins = ['http://127.0.0.1:3216']
require 'puma'
server = Puma::Server.new(Rails.application)
server.add_tcp_listener('127.0.0.1', 3216)
server.run.join
