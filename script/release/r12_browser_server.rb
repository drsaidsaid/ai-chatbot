# frozen_string_literal: true

require 'json'

database = ActiveRecord::Base.connection_db_config.database
allowed_database = ENV.fetch('R12_BROWSER_DATABASE', nil)
abort 'Disposable R12 browser database only' unless Rails.env.test? && database == allowed_database &&
                                                    database&.match?(/\Aale_r12_[a-z0-9_]+_browser\z/)

require 'webmock'
WebMock.enable!
WebMock.disable_net_connect!(allow_localhost: true)
ActiveJob::Base.queue_adapter = :test
ActionMailer::Base.delivery_method = :test
at_exit do
  adapter = ActiveJob::Base.queue_adapter
  puts({
    r12_runtime_evidence: {
      enqueued_jobs: adapter.respond_to?(:enqueued_jobs) ? adapter.enqueued_jobs.size : nil,
      performed_jobs: adapter.respond_to?(:performed_jobs) ? adapter.performed_jobs.size : nil,
      delivered_mail: ActionMailer::Base.deliveries.size
    }
  }.to_json)
end
ViteRuby.reload_with(mode: 'production', auto_build: false, public_output_dir: 'vite')
Rails.application.routes.default_url_options = { host: '127.0.0.1', port: 3212 }
ActionMailer::Base.default_url_options = { host: '127.0.0.1', port: 3212 }
ActionCable.server.config.cable = {
  'adapter' => 'redis',
  'url' => ENV.fetch('REDIS_URL'),
  'channel_prefix' => 'r12_browser'
}
ActionCable.server.config.allowed_request_origins = ['http://127.0.0.1:3212', 'http://localhost:3212']

require 'puma'
server = Puma::Server.new(Rails.application)
server.add_tcp_listener('127.0.0.1', 3212)
server.run.join
