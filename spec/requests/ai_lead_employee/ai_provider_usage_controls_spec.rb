# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI provider usage controls', type: :request do
  self.use_transactional_tests = false

  before { clean_committed_fixtures }
  after { clean_committed_fixtures }

  it 'retains provider usage when an evaluation transaction rolls back', :aggregate_failures do
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    create(:ai_provider_connection, account: account, daily_request_limit: 10)
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .to_return(
        status: 200,
        body: {
          id: 'chatcmpl-evaluation-rollback',
          choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }],
          usage: { prompt_tokens: 4, completion_tokens: 2, total_tokens: 6 }
        }.to_json
      )

    provider_response = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      provider_response = AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
        messages: [{ role: 'user', content: 'Synthetic evaluation question' }],
        purpose: 'evaluation'
      )
      raise ActiveRecord::Rollback
    end

    get "/api/v1/accounts/#{account.id}/ai_provider_connection", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'managed_service' => true,
      'requests_used_today' => 1
    )
    expect(response.parsed_body).not_to have_key('cost_usd_today')
    expect(provider_response).to have_attributes(
      configuration_version: account.ai_provider_connection.configuration_version,
      usage_period_on: Time.current.utc.to_date
    )
  end

  it 'records the real sandbox provider path as evaluation usage outside its rollback', :aggregate_failures do
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(
      status: 200,
      body: {
        id: 'provider-response-eval',
        model: 'openai/gpt-5.2',
        choices: [{ message: { content: 'Yes, we build AI employees.' }, finish_reason: 'stop' }]
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    result = AiLeadEmployee::Evaluation::SandboxRunner.new(
      account: account,
      user: admin,
      scenario_key: 'approved_answer'
    ).perform

    expect(result.run).to be_completed
    expect(connection.usages.sole).to have_attributes(purpose: 'evaluation')
  end

  it 'allows only one concurrent worker to reserve the final daily request slot', :aggregate_failures do
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    create(:ai_provider_connection, account: account, daily_request_limit: 1)
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
              .to_return do
      sleep 0.2
      {
        status: 200,
        body: {
          id: 'chatcmpl-final-slot',
          choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }]
        }.to_json
      }
    end
    start = Queue.new
    results = Queue.new
    workers = Array.new(2) do
      Thread.new do
        start.pop
        ActiveRecord::Base.connection_pool.with_connection do
          client = AiLeadEmployee::AiProvider::ClientFactory.for(account: Account.find(account.id))
          results << client.complete(messages: [{ role: 'user', content: 'Compete for the final slot' }])
        rescue StandardError => e
          results << e
        end
      end
    end

    workers.size.times { start << true }
    workers.each(&:join)
    outcomes = Array.new(workers.size) { results.pop }

    expect(request).to have_been_requested.once
    expect(outcomes.count { |outcome| outcome.is_a?(AiLeadEmployee::AiProvider::Response) }).to eq(1)
    expect(outcomes.count { |outcome| outcome.is_a?(AiLeadEmployee::AiProvider::UsageLimitFailure) }).to eq(1)

    get "/api/v1/accounts/#{account.id}/ai_provider_connection", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('requests_used_today' => 1)
  ensure
    workers&.each(&:join)
  end

  it 'ignores mismatched legacy usage rows for runtime admission and pause state', :aggregate_failures do
    account = create(:account)
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 1)
    other_connection = create(:ai_provider_connection, account: create(:account), daily_request_limit: 1)
    mismatched_usage = AiLeadEmployee::AiProviderUsage.create!(
      account: other_connection.account,
      ai_provider_connection: other_connection,
      configuration_version: other_connection.configuration_version,
      purpose: 'answer',
      period_on: Time.current.utc.to_date,
      status: 'completed',
      requested_output_tokens: other_connection.reply_token_limit,
      started_at: Time.current,
      completed_at: Time.current,
      cost_available: false
    )
    mismatched_usage.ai_provider_connection_id = connection.id
    mismatched_usage.save!(validate: false)
    provider_request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
                       .to_return(
                         status: 200,
                         body: {
                           id: 'chatcmpl-account-isolation',
                           choices: [{ message: { role: 'assistant', content: 'ok' }, finish_reason: 'stop' }]
                         }.to_json
                       )

    expect(
      AiLeadEmployee::AiProvider::RuntimeControl.failure_code(account: account)
    ).to be_nil
    expect(connection.reload.automation_paused_reason).to be_nil

    response = AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
      messages: [{ role: 'user', content: 'Use only this account allowance' }]
    )

    expect(response.id).to eq('chatcmpl-account-isolation')
    expect(provider_request).to have_been_requested.once
    expect(connection.usages.where(account_id: account.id).count).to eq(1)
    expect(connection.reload.automation_paused_reason).to eq('usage_limit_exhausted')
  end

  it 'rechecks provider permission when a previously created client starts a request', :aggregate_failures do
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    client = AiLeadEmployee::AiProvider::ClientFactory.for(account: account)
    provider_request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')

    connection.disable!

    expect do
      client.complete(messages: [{ role: 'user', content: 'Do not send with a stale client' }])
    end.to raise_error(AiLeadEmployee::AiProvider::DisabledFailure)
    expect(provider_request).not_to have_been_requested

    get "/api/v1/accounts/#{account.id}/ai_provider_connection", headers: admin.create_new_auth_token, as: :json
    expect(response.parsed_body).to include('requests_used_today' => 0, 'automation_paused_reason' => 'provider_disabled')
  end

  it 'rejects oversized provider input before reserving usage or making an HTTP request', :aggregate_failures do
    account = create(:account)
    create(:ai_provider_connection, account: account, daily_request_limit: 10)
    provider_request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')

    oversized_inputs = [
      'x' * 32_769,
      'jibu🙂' * 5_000
    ]
    oversized_inputs.each do |content|
      expect(content.bytesize).to be > 32.kilobytes
      expect do
        AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
          messages: [{ role: 'user', content: content }]
        )
      end.to raise_error(AiLeadEmployee::AiProvider::InputLimitFailure)
    end

    expect(provider_request).not_to have_been_requested
    expect(AiLeadEmployee::AiProviderUsage.where(account: account)).to be_empty
  end

  it 'rejects output above the configured ceiling before reserving usage or making an HTTP request', :aggregate_failures do
    account = create(:account)
    create(:ai_provider_connection, account: account, reply_token_limit: 512, daily_request_limit: 10)
    provider_request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')

    [0, 513].each do |max_tokens|
      expect do
        AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
          messages: [{ role: 'user', content: 'Bound this output' }],
          max_tokens: max_tokens
        )
      end.to raise_error(AiLeadEmployee::AiProvider::OutputLimitFailure)
    end

    expect(provider_request).not_to have_been_requested
    expect(AiLeadEmployee::AiProviderUsage.where(account: account)).to be_empty
  end

  it 'supersedes an older healthy observation when a real model request fails', :aggregate_failures do
    account = create(:account)
    connection = create(
      :ai_provider_connection,
      account: account,
      daily_request_limit: 10,
      last_health_status: 'healthy',
      last_health_checked_at: 1.hour.ago,
      last_health_configuration_version: 1
    )
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .to_return(status: 402, body: { error: { message: 'Synthetic insufficient credits' } }.to_json)

    expect do
      AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
        messages: [{ role: 'user', content: 'A real model request' }]
      )
    end.to raise_error(AiLeadEmployee::AiProvider::InsufficientCreditsFailure)

    expect(connection.reload).to have_attributes(
      readiness_status: 'failed',
      last_health_failure_class: 'insufficient_credits',
      last_health_configuration_version: 1
    )
    expect(connection.usages.failed.sole.failure_class).to eq('insufficient_credits')
  end

  it 'does not let a slower older health success overwrite a newer real failure', :aggregate_failures do
    account = create(:account)
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    health_entered = Queue.new
    release_health = Queue.new
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do |request|
      prompt = JSON.parse(request.body).fetch('messages').last.fetch('content')
      if prompt == 'Reply with ok.'
        health_entered << true
        release_health.pop
        {
          status: 200,
          body: { id: 'older-health', model: connection.model,
                  choices: [{ message: { content: 'ok' }, finish_reason: 'stop' }] }.to_json
        }
      else
        { status: 402, body: { error: { message: 'Synthetic later failure' } }.to_json }
      end
    end
    health_result = Queue.new
    health_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        health_result << AiLeadEmployee::AiProvider::HealthCheck.new(connection: connection.reload).perform
      end
    end
    Timeout.timeout(10) { health_entered.pop }

    expect do
      AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
        messages: [{ role: 'user', content: 'Observe the later real failure' }]
      )
    end.to raise_error(AiLeadEmployee::AiProvider::InsufficientCreditsFailure)
    release_health << true
    health_worker.value

    expect(health_result.pop.status).to eq('stale')
    expect(connection.reload).to have_attributes(
      readiness_status: 'failed',
      last_health_failure_class: 'insufficient_credits'
    )
  ensure
    release_health << true if release_health
    health_worker&.join
  end

  it 'admits real evaluation usage without waiting on the caller transaction pool connection', :aggregate_failures do
    original_config = ActiveRecord::Base.connection_db_config.configuration_hash
    ActiveRecord::Base.establish_connection(original_config.merge(pool: 1, checkout_timeout: 0.2))
    account = create(:account)
    admin = create(:user, :administrator, account: account)
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    create(:knowledge_item, account: account, question: 'Do you offer AI employees?', answer: 'Yes, we build AI employees.')
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(
      status: 200,
      body: { id: 'bounded-pool-evaluation', model: connection.model,
              choices: [{ message: { content: 'Yes, we build AI employees.' }, finish_reason: 'stop' }] }.to_json
    )

    result = Timeout.timeout(2) do
      AiLeadEmployee::Evaluation::SandboxRunner.new(account: account, user: admin, scenario_key: 'approved_answer').perform
    end

    expect(result.run).to be_completed
    expect(request).to have_been_requested.once
    expect(connection.usages.sole).to have_attributes(purpose: 'evaluation')
  ensure
    ActiveRecord::Base.establish_connection(original_config) if original_config
  end

  it 'fails closed before provider HTTP when the bounded usage ledger pool is unavailable', :aggregate_failures do
    account = create(:account)
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    provider_request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
    pool = AiLeadEmployee::AiProviderLedgerRecord.connection_pool
    occupied = Queue.new
    release = Queue.new
    workers = Array.new(pool.size) do
      Thread.new do
        pool.with_connection do
          occupied << true
          release.pop
        end
      end
    end
    workers.size.times { Timeout.timeout(5) { occupied.pop } }

    expect do
      Timeout.timeout(3) do
        ActiveRecord::Base.transaction do
          AiLeadEmployee::AiProvider::ClientFactory.for(account: account).complete(
            messages: [{ role: 'user', content: 'Do not call the provider without durable admission' }]
          )
        end
      end
    end.to raise_error(AiLeadEmployee::AiProvider::AdmissionUnavailableFailure)
    expect(provider_request).not_to have_been_requested
    expect(connection.usages).to be_empty
  ensure
    workers&.size&.times { release << true }
    workers&.each(&:join)
  end

  private

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
