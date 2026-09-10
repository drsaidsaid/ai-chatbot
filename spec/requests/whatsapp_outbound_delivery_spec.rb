require 'rails_helper'

RSpec.describe 'Canonical WhatsApp outgoing delivery', type: :request do
  self.use_transactional_tests = false

  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:admin) { create(:user, :administrator, account: channel.account) }
  let(:conversation) { create(:conversation, account: channel.account, inbox: channel.inbox, assignee: admin, control_state: :human_active) }
  let(:outgoing) do
    create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                     sender: admin, message_type: :outgoing, content: 'Your reply, once.')
  end
  let(:provider_url) { %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages} }

  before do
    clean_committed_fixtures
    create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                     message_type: :incoming, provider_created_at: Time.current)
  end

  after { clean_committed_fixtures }

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end

  def approve_launch!
    connection = channel.account.ai_provider_connection || create(:ai_provider_connection, account: channel.account)
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |scenario_key|
      attributes = { account: channel.account, user: admin, scenario_key: scenario_key }
      if connection
        attributes[:provider_snapshot] = {
          'provider' => connection.provider,
          'model' => connection.model,
          'configuration_version' => connection.configuration_version
        }
      end
      create(:ai_lead_employee_evaluation_run, :reviewed_pass, **attributes)
    end
    evaluator = AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: channel.account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: 3)
    evaluator.approve!(user: admin, notes: 'Synthetic R04 local test evidence only')
  end

  it 'allows only one independent worker to dispatch the same outgoing Message' do
    request = stub_request(:post, provider_url).to_return do
      sleep 0.2
      { status: 200, body: { messages: [{ id: 'wamid.R04.ONCE' }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
    message_id = outgoing.id
    start = Queue.new
    workers = Array.new(2) do
      Thread.new do
        start.pop
        ActiveRecord::Base.connection_pool.with_connection { SendReplyJob.perform_now(message_id) }
      end
    end
    workers.size.times { start << true }
    workers.each(&:value)

    expect(request).to have_been_requested.once
    expect(outgoing.reload.source_id).to eq('wamid.R04.ONCE')
  ensure
    workers&.each(&:join)
  end

  it 'shows unknown acceptance after a provider timeout and does not send again on job retry' do
    request = stub_request(:post, provider_url).to_timeout

    SendReplyJob.perform_now(outgoing.id)
    SendReplyJob.perform_now(outgoing.id)

    get "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages", headers: admin.create_new_auth_token
    expect(response).to have_http_status(:ok)
    payload = response.parsed_body.fetch('payload').find { |row| row['id'] == outgoing.id }
    expect(payload.dig('content_attributes', 'whatsapp_delivery', 'state')).to eq('unknown')
    expect(request).to have_been_requested.once
    expect(HumanReviewRequest.where(conversation: conversation, reason: :delivery_unknown).count).to eq(1)
  end

  it 'cancels an already recorded AI reply when a Human Operator takes over' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    reply = create(:message, :bot_message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                           sender: nil, message_type: :outgoing, content: 'Pending AI answer')
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.TOO.LATE"}]}')

    broadcasts = []
    allow(ActionCable.server).to receive(:broadcast).and_wrap_original do |original, stream, payload|
      broadcasts << payload.deep_dup if stream == admin.pubsub_token && payload[:event] == 'message.updated' && payload.dig(:data, 'id') == reply.id
      original.call(stream, payload)
    end
    clear_enqueued_jobs
    perform_enqueued_jobs(only: ActionCableBroadcastJob) do
      Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin)
      SendReplyJob.perform_now(reply.id)
    end

    expect(broadcasts.last.dig(:data, 'content_attributes', 'whatsapp_delivery', 'state')).to eq('canceled')
    expect(reply.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('canceled')
    expect(request).not_to have_been_requested
  end

  it 'records a definite provider rejection as failed and reserves retry for an authorized operator' do
    request = stub_request(:post, provider_url).to_return(status: 400, body: '{"error":{"code":100,"message":"invalid parameter"}}',
                                                          headers: { 'Content-Type' => 'application/json' })
    SendReplyJob.perform_now(outgoing.id)
    SendReplyJob.perform_now(outgoing.id)

    expect(outgoing.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('failed')
    expect(request).to have_been_requested.once
    expect(HumanReviewRequest.count).to eq(0)
  end

  it 'keeps provider acceptance distinct from projected sent history through the Message API' do
    stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.RECEIPT.HISTORY"}]}',
                                                headers: { 'Content-Type' => 'application/json' })
    SendReplyJob.perform_now(outgoing.id)
    path = "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages"
    headers = admin.create_new_auth_token
    get path, headers: headers
    accepted = response.parsed_body.fetch('payload').find { |row| row['id'] == outgoing.id }
    expect(accepted.dig('content_attributes', 'whatsapp_delivery', 'state')).to eq('accepted')
    expect(accepted.dig('content_attributes', 'whatsapp_provider_status')).to be_nil

    Whatsapp::MessageStatusProjector.new(message: outgoing.reload, status: { status: 'sent', timestamp: Time.current.to_i.to_s }).perform
    get path, headers: headers
    sent = response.parsed_body.fetch('payload').find { |row| row['id'] == outgoing.id }
    expect(sent.dig('content_attributes', 'whatsapp_provider_status')).to eq('sent')
    expect(sent.dig('content_attributes', 'whatsapp_delivery', 'state')).to eq('accepted')
  end

  [
    [200, '{"messages":[{"id":"wamid.LIVE.RECEIPT"}]}', 'accepted'],
    [400, '{"error":{"code":100,"message":"Synthetic rejection"}}', 'failed'],
    [503, '{"error":{"code":2,"message":"Synthetic uncertain outcome"}}', 'unknown']
  ].each do |http_status, body, expected_state|
    it "broadcasts the committed #{expected_state} outcome for an actual API-created reply" do
      path = "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages"
      headers = admin.create_new_auth_token
      post path, headers: headers, params: { content: 'Browser-created reply outcome' }, as: :json
      message = conversation.messages.outgoing.sole
      broadcasts = []
      allow(ActionCable.server).to receive(:broadcast).and_wrap_original do |original, stream, payload|
        broadcasts << payload.deep_dup if stream == admin.pubsub_token && payload[:event] == 'message.updated' && payload.dig(:data,
                                                                                                                              'id') == message.id
        original.call(stream, payload)
      end
      request = stub_request(:post, provider_url).to_return(status: http_status, body: body, headers: { 'Content-Type' => 'application/json' })
      clear_enqueued_jobs
      perform_enqueued_jobs(only: ActionCableBroadcastJob) { SendReplyJob.perform_now(message.id) }
      get path, headers: headers
      saved = response.parsed_body.fetch('payload').find { |row| row['id'] == message.id }
      live = broadcasts.last.fetch(:data).deep_stringify_keys
      expect(live.dig('content_attributes', 'whatsapp_delivery', 'state')).to eq(expected_state)
      expect(live.slice('status', 'source_id', 'content_attributes')).to eq(saved.slice('status', 'source_id', 'content_attributes'))
      expect(live.fetch('previous_changes')).to be_present
      perform_enqueued_jobs(only: ActionCableBroadcastJob) { 3.times { SendReplyJob.perform_now(message.id) } }
      expect(request).to have_been_requested.once
      expect(HumanReviewRequest.where(lead_message_id: message.id, reason: :delivery_unknown).count).to eq(expected_state == 'unknown' ? 1 : 0)
    end
  end

  it 'keeps terminal outcomes when the originally queued creation broadcast runs after dispatch updates' do
    fixture_path = Rails.root.join('app/javascript/dashboard/components-next/message/specs/fixtures/whatsappCreatedOrdering.json')
    projection = ->(payload) { payload.deep_stringify_keys.slice('status', 'source_id', 'content_attributes', 'echo_id') }
    actual = [['accepted', 200], ['unknown', 503]].map do |expected_state, http_status|
      clear_enqueued_jobs
      path = "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages"
      post path, headers: admin.create_new_auth_token, params: { content: "Queued creation #{expected_state}", echo_id: "echo-#{expected_state}" },
                 as: :json
      message = conversation.messages.outgoing.order(:id).last
      created_job = enqueued_jobs.select { |job| job[:job] == ActionCableBroadcastJob && job[:args][1] == 'message.created' }.sole
      creation_data = ActiveJob::Arguments.deserialize(created_job.fetch('arguments'))[2]
      broadcasts = []
      allow(ActionCable.server).to receive(:broadcast) do |stream, payload|
        broadcasts << payload.deep_dup if stream == admin.pubsub_token && payload.dig(:data, 'id') == message.id
      end
      body = http_status == 200 ? '{"messages":[{"id":"wamid.CREATED.ORDER"}]}' : '{"error":{"code":2}}'
      stub_request(:post, provider_url).to_return(status: http_status, body: body, headers: { 'Content-Type' => 'application/json' })
      clear_enqueued_jobs
      perform_enqueued_jobs(only: ActionCableBroadcastJob) { SendReplyJob.perform_now(message.id) }
      updated = broadcasts.last.fetch(:data)
      ActiveJob::Base.execute(created_job)
      { 'case' => expected_state, 'pending_creation' => projection.call(creation_data),
        'updated' => projection.call(updated), 'late_creation' => projection.call(broadcasts.last.fetch(:data)) }
    end
    Rails.root.join('tmp/whatsapp_created_ordering.json').write(JSON.pretty_generate(actual))
    actual.each do |item|
      expect(item.dig('pending_creation', 'content_attributes', 'whatsapp_delivery', 'state')).to eq('pending')
      expect(item.dig('late_creation', 'content_attributes', 'whatsapp_delivery', 'state')).to eq(item.fetch('case'))
      expect(item.dig('late_creation', 'echo_id')).to eq("echo-#{item.fetch('case')}")
    end
    expect(actual).to eq(JSON.parse(fixture_path.read))
  end

  it 'broadcasts pending when the operator retries a definite failure through the Inbox API' do
    stub_request(:post, provider_url).to_return(status: 400, body: '{"error":{"code":100}}', headers: { 'Content-Type' => 'application/json' })
    SendReplyJob.perform_now(outgoing.id)
    broadcasts = []
    allow(ActionCable.server).to receive(:broadcast) { |stream, payload|
      broadcasts << payload if stream == admin.pubsub_token && payload[:event] == 'message.updated'
    }
    clear_enqueued_jobs
    perform_enqueued_jobs(only: ActionCableBroadcastJob) do
      post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages/#{outgoing.id}/retry",
           headers: admin.create_new_auth_token
    end

    expect(response).to have_http_status(:ok)
    retry_live = broadcasts.last.fetch(:data)
    expect(retry_live.dig('content_attributes', 'whatsapp_delivery', 'state')).to eq('pending')
    expect(retry_live).to include('status' => 'sent', 'source_id' => nil)
  end

  it 'broadcasts a later provider failure without losing the accepted delivery identity' do
    stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.LIVE.RECEIPT"}]}',
                                                headers: { 'Content-Type' => 'application/json' })
    SendReplyJob.perform_now(outgoing.id)
    broadcasts = []
    allow(ActionCable.server).to receive(:broadcast) { |stream, payload|
      broadcasts << payload if stream == admin.pubsub_token && payload[:event] == 'message.updated'
    }
    clear_enqueued_jobs
    perform_enqueued_jobs(only: ActionCableBroadcastJob) do
      Whatsapp::MessageStatusProjector.new(message: outgoing.reload, status: { status: 'failed', timestamp: Time.current.to_i.to_s }).perform
    end

    receipt = broadcasts.last.fetch(:data)
    expect(receipt).to include('status' => 'failed', 'source_id' => 'wamid.LIVE.RECEIPT')
    expect(receipt.dig('content_attributes', 'whatsapp_delivery', 'state')).to eq('accepted')
    expect(receipt.dig('content_attributes', 'whatsapp_provider_status')).to eq('failed')
  end

  it 'rejects client-supplied provider receipt evidence when creating an outgoing Message' do
    post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages",
         headers: admin.create_new_auth_token,
         params: { content: 'Wait for a real receipt', content_attributes: {
           whatsapp_provider_status: 'sent', whatsapp_delivery_timestamp: Time.current.to_i, whatsapp_delivery_error_code: '190'
         } }, as: :json
    expect(response).to have_http_status(:ok)
    message = conversation.messages.outgoing.sole
    expect(message.content_attributes).not_to include('whatsapp_provider_status', 'whatsapp_delivery_timestamp', 'whatsapp_delivery_error_code')
    expect(message.whatsapp_outbound_delivery).to be_pending
  end

  it 'does not allow the creation API to impersonate a provider-accepted echo' do
    post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages",
         headers: admin.create_new_auth_token, params: {
           content: 'Client metadata is not provider evidence', source_id: 'wamid.FORGED',
           content_attributes: { external_echo: true, whatsapp_delivery: { state: 'accepted' }, whatsapp_provider_status: 'sent' }
         }, as: :json
    expect(response).to have_http_status(:ok)
    message = conversation.messages.outgoing.sole
    expect(message.source_id).to be_nil
    expect(message.content_attributes).not_to include('external_echo', 'whatsapp_provider_status')
    expect(message.whatsapp_outbound_delivery).to be_pending
  end

  it 'keeps every supported client evidence alias out of accepted Message API history' do
    fixture_path = Rails.root.join('app/javascript/dashboard/components-next/message/specs/fixtures/whatsappReceiptAliases.json')
    cases = JSON.parse(fixture_path.read)
    actual = cases.map.with_index do |item, index|
      headers = admin.create_new_auth_token
      path = "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages"
      post path, headers: headers, params: { content: 'Wait for the provider receipt', content_attributes: item.fetch('client_attributes') },
                 as: :json
      expect(response).to have_http_status(:ok)
      message = conversation.messages.outgoing.order(:id).last
      provider_id = "wamid.ALIAS.#{index}"
      stub_request(:post, provider_url).to_return(status: 200, body: { messages: [{ id: provider_id }] }.to_json,
                                                  headers: { 'Content-Type' => 'application/json' })
      SendReplyJob.perform_now(message.id)
      get path, headers: headers
      payload = response.parsed_body.fetch('payload').find { |row| row['id'] == message.id }
      item.merge('accepted_message' => payload.slice('status', 'source_id', 'content_attributes'))
    end
    # The frontend contract fixture is captured from actual HTTP responses, never
    # assembled by a second sanitizer. Future runs compare that same contract.
    Rails.root.join('tmp/whatsapp_receipt_aliases_api.json').write(JSON.pretty_generate(actual))
    actual.each do |item|
      expect(item.dig('accepted_message', 'content_attributes')).to eq(
        'operator_note' => 'Keep this ordinary attribute', 'notes' => { 'whatsappProviderStatus' => 'Preserve nested customer data' },
        'whatsapp_delivery' => { 'state' => 'accepted', 'failure_code' => nil }
      )
    end
    expect(actual).to eq(cases)
  end

  it 'recovers an outgoing Message committed during a queue outage without asking the operator to recreate it' do
    adapter_class = Class.new do
      def enqueue(*)
        raise IOError, 'synthetic queue unavailable'
      end
      alias_method :enqueue_at, :enqueue
    end
    stub_const('OutboundUnavailableQueueAdapter', adapter_class)
    previous_adapter = SendReplyJob.queue_adapter
    SendReplyJob.queue_adapter = adapter_class.new
    expect { outgoing }.not_to raise_error
    SendReplyJob.queue_adapter = previous_adapter
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.RECOVERED"}]}',
                                                          headers: { 'Content-Type' => 'application/json' })

    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }

    expect(outgoing.reload.source_id).to eq('wamid.RECOVERED')
    expect(request).to have_been_requested.once
  ensure
    SendReplyJob.queue_adapter = previous_adapter if previous_adapter
  end

  it 'allows prompt human takeover while the model is still working and discards its late answer' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    create(:ai_provider_connection, account: channel.account)
    approve_launch!
    create(:knowledge_item, account: channel.account, question: 'Do you offer AI employees?', answer: 'We build AI employees for businesses.')
    incoming = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                message_type: :incoming, content: 'Do you offer AI employees?', provider_created_at: Time.current)
    intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: incoming, enqueue: false).perform
    entered = Queue.new
    release = Queue.new
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do
      entered << true
      release.pop
      { status: 200,
        body: { id: 'r04-model', model: 'synthetic',
                choices: [{ finish_reason: 'stop', message: { content: 'We build AI employees for businesses.' } }] }.to_json }
    end
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }
    end
    Timeout.timeout(10) { entered.pop }

    Timeout.timeout(2) { Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin) }
    expect(conversation.reload).to be_human_active
    release << true
    worker.value
    expect(intent.reload).to be_blocked
    expect(conversation.messages.outgoing.count).to eq(0)
  ensure
    release << true if release
    worker&.join
  end

  it 'discards an in-flight answer after a provider configuration change commits before cancellation' do # rubocop:disable RSpec/ExampleLength
    conversation.update!(control_state: :ai_active, assignee: nil)
    connection = create(:ai_provider_connection, account: channel.account)
    approve_launch!
    create(:knowledge_item, account: channel.account, question: 'Do you offer AI employees?', answer: 'We build AI employees for businesses.')
    incoming = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                message_type: :incoming, content: 'Do you offer AI employees?', provider_created_at: Time.current)
    intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: incoming, enqueue: false).perform
    provider_entered = Queue.new
    release_provider = Queue.new
    cancellation_entered = Queue.new
    release_cancellation = Queue.new
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do |request|
      expect(JSON.parse(request.body)).to include('max_tokens' => connection.reply_token_limit)
      provider_entered << true
      release_provider.pop
      { status: 200,
        body: { id: 'r10-old-configuration', model: connection.model,
                choices: [{ finish_reason: 'stop', message: { content: 'We build AI employees for businesses.' } }] }.to_json }
    end
    allow(AiLeadEmployee::AiProvider::RuntimeControl).to receive(:stop_pending_automation!).and_wrap_original do |original, **args|
      cancellation_entered << true
      release_cancellation.pop
      original.call(**args)
    end
    job_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }
    end
    Timeout.timeout(10) { provider_entered.pop }

    session = ActionDispatch::Integration::Session.new(Rails.application)
    headers = admin.create_new_auth_token
    update_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        session.patch(
          "/api/v1/accounts/#{channel.account_id}/ai_provider_connection",
          headers: headers,
          params: { model: 'openai/gpt-5.2', reply_token_limit: 256, daily_request_limit: 100 },
          as: :json
        )
      end
    end
    Timeout.timeout(10) { cancellation_entered.pop }
    expect(connection.reload.configuration_version).to eq(2)

    release_provider << true
    job_worker.value

    expect(intent.reload).to have_attributes(state: 'blocked', blocked_reason: 'provider_configuration_changed')
    expect(conversation.messages.outgoing.count).to eq(0)
  ensure
    release_provider << true if release_provider
    release_cancellation << true if release_cancellation
    job_worker&.join
    update_worker&.join
  end

  it 'serializes final send authorization with provider revocation' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    connection = create(:ai_provider_connection, account: channel.account, daily_request_limit: 10)
    approve_launch!
    reply = create(:message, :bot_message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                           sender: nil, message_type: :outgoing, content: 'Already authorized answer')
    provider_request = stub_request(:post, provider_url)
                       .to_return(status: 200, body: { messages: [{ id: 'wamid.R10.AUTHORIZED' }] }.to_json,
                                  headers: { 'Content-Type' => 'application/json' })
    authorization_read = Queue.new
    release_authorization = Queue.new
    allow(AiLeadEmployee::AiProvider::RuntimeControl).to receive(:failure_code).and_wrap_original do |original, **args|
      result = original.call(**args)
      authorization_read << true
      release_authorization.pop
      result
    end
    send_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { SendReplyJob.perform_now(reply.id) }
    end
    Timeout.timeout(10) { authorization_read.pop }

    session = ActionDispatch::Integration::Session.new(Rails.application)
    headers = admin.create_new_auth_token
    update_started = Queue.new
    update_worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        update_started << true
        session.patch(
          "/api/v1/accounts/#{channel.account_id}/ai_provider_connection",
          headers: headers,
          params: { model: 'openai/gpt-5.2', reply_token_limit: 512, daily_request_limit: 10 },
          as: :json
        )
      end
    end
    update_started.pop
    sleep 0.2

    expect(connection.reload.configuration_version).to eq(1)

    release_authorization << true
    send_worker.value
    update_worker.value

    expect(reply.reload.source_id).to eq('wamid.R10.AUTHORIZED'), reply.whatsapp_outbound_delivery.attributes.inspect
    expect(provider_request).to have_been_requested.once
    expect(connection.reload.configuration_version).to eq(2)
  ensure
    release_authorization << true if release_authorization
    send_worker&.join
    update_worker&.join
  end

  it 'never revives provider output admitted on an earlier UTC allowance day' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    connection = create(:ai_provider_connection, account: channel.account, daily_request_limit: 1)
    approve_launch!
    admitted_on = Time.current.utc.to_date - 1.day
    usage = AiLeadEmployee::AiProviderUsage.create!(
      account: channel.account,
      ai_provider_connection: connection,
      configuration_version: connection.configuration_version,
      purpose: 'answer',
      period_on: admitted_on,
      status: 'completed',
      requested_output_tokens: connection.reply_token_limit,
      started_at: 1.day.ago,
      completed_at: 1.day.ago
    )
    reply = create(
      :message,
      :bot_message,
      account: channel.account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: nil,
      message_type: :outgoing,
      content: 'Yesterday provider output must stay canceled',
      additional_attributes: {
        ai_lead_employee: {
          orchestration_intent_id: 123_456,
          provider_configuration_version: usage.configuration_version,
          provider_usage_period_on: usage.period_on.iso8601
        }
      }
    )
    provider_request = stub_request(:post, provider_url)

    SendReplyJob.perform_now(reply.id)

    delivery = reply.reload.whatsapp_outbound_delivery
    expect(delivery).to have_attributes(state: 'canceled', failure_code: 'provider_usage_period_expired')
    expect(provider_request).not_to have_been_requested
  end

  it 'recovers an expired pre-dispatch claim but never reclaims dispatch-started work' do
    outgoing.whatsapp_outbound_delivery.update!(state: :claimed, owner_token: 'dead-before-dispatch', attempts: 1, lease_expires_at: 1.minute.ago)
    other = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                             sender: admin, message_type: :outgoing, content: 'Acceptance might have happened')
    other.whatsapp_outbound_delivery.update!(state: :dispatching, owner_token: 'dead-after-dispatch', attempts: 1,
                                             dispatch_started_at: 2.minutes.ago, lease_expires_at: 1.minute.ago)
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.RECLAIMED"}]}',
                                                          headers: { 'Content-Type' => 'application/json' })
    clear_enqueued_jobs

    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }

    expect(outgoing.reload.source_id).to eq('wamid.RECLAIMED')
    expect(other.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('unknown')
    expect(request).to have_been_requested.once
    expect(HumanReviewRequest.where(lead_message: other, reason: :delivery_unknown).count).to eq(1)
  end

  %w[assignment pause closure resolved private_note human_reply opt_out launch_withdrawal].each do |action|
    it "invalidates pending automation immediately after #{action}" do
      conversation.update!(control_state: :ai_active, assignee: nil)
      approve_launch!
      reply = create(:message, :bot_message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                             sender: nil, message_type: :outgoing, content: 'Pending answer')

      case action
      when 'assignment'
        Conversations::AssignmentService.new(conversation: conversation, assignee_id: admin.id).perform
      when 'pause'
        Conversations::ControlService.new(conversation: conversation).pause_ai!
      when 'closure'
        Conversations::ControlService.new(conversation: conversation).close!
      when 'resolved'
        conversation.update!(status: :resolved)
      when 'private_note', 'human_reply'
        post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages",
             headers: admin.create_new_auth_token, params: { content: 'Human is reviewing this.', private: action == 'private_note' }
        expect(response).to have_http_status(:ok)
      when 'opt_out'
        LeadFollowUpOptOut.create!(account: channel.account, contact: conversation.contact, reason: 'requested', opted_out_at: Time.current)
      when 'launch_withdrawal'
        AiLeadEmployee::LaunchGate.find_by!(account: channel.account).update!(approved_at: nil)
      end

      expect(reply.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('canceled')
    end
  end

  it 'rejects an Inbox retry for unknown acceptance and keeps the original delivery evidence' do
    request = stub_request(:post, provider_url).to_timeout
    SendReplyJob.perform_now(outgoing.id)

    post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages/#{outgoing.id}/retry",
         headers: admin.create_new_auth_token

    expect(response).to have_http_status(:conflict)
    expect(outgoing.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('unknown')
    expect(request).to have_been_requested.once
  end

  it 'keeps a timed-out domain outbox event unknown instead of claiming it was delivered' do
    event = OutboxEvent.create!(account: channel.account, aggregate: outgoing, event_type: 'ai_employee.outbound_intent_recorded',
                                idempotency_key: 'r04-outbox-unknown', payload: { message_id: outgoing.id })
    request = stub_request(:post, provider_url).to_timeout

    AiLeadEmployee::OutboxDispatchJob.perform_now(event.id)
    AiLeadEmployee::OutboxDispatchJob.perform_now(event.id)

    expect(event.reload.state).to eq('unknown')
    expect(event.delivered_at).to be_nil
    expect(request).to have_been_requested.once
  end

  it 'commits the first Channel Greeting before a failed after-commit enqueue and recovers it once' do
    channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome. How can we help?')
    approve_launch!
    raw = { object: 'whatsapp_business_account', entry: [{ id: channel.provider_config['business_account_id'], changes: [{
      field: 'messages', value: {
        metadata: { phone_number_id: channel.provider_config['phone_number_id'], display_phone_number: channel.phone_number.delete_prefix('+') },
        contacts: [{ wa_id: '255700000094', profile: { name: 'Synthetic Lead' } }],
        messages: [{ id: 'wamid.R04.GREETING', from: '255700000094', timestamp: Time.current.to_i.to_s,
                     type: 'text', text: { body: 'Hello, I have a question.' } }]
      }
    }] }] }.to_json
    signature = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', channel.provider_config['app_secret'], raw)}"
    post "/webhooks/whatsapp/#{channel.phone_number}", params: raw,
                                                       headers: { 'CONTENT_TYPE' => 'application/json', 'HTTP_X_HUB_SIGNATURE_256' => signature }
    expect(response).to have_http_status(:ok)
    saved_receipt = Whatsapp::WebhookReceipt.last
    adapter_class = Class.new do
      def enqueue(*)
        raise IOError, 'synthetic queue unavailable'
      end
      alias_method :enqueue_at, :enqueue
    end
    stub_const('GreetingUnavailableQueueAdapter', adapter_class)
    previous_adapter = SendReplyJob.queue_adapter
    SendReplyJob.queue_adapter = adapter_class.new
    Webhooks::WhatsappEventsJob.perform_now(saved_receipt.id)
    SendReplyJob.queue_adapter = previous_adapter
    received = channel.inbox.messages.find_by!(source_id: 'wamid.R04.GREETING')
    expect(received.conversation.messages.template.count).to eq(1)
    greeting = received.conversation.messages.template.sole
    expect(greeting.content_attributes.dig('whatsapp_delivery', 'state')).to eq('pending')
    expect(AiLeadEmployee::OrchestrationIntent.where(triggering_message: received).count).to eq(1)
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.GREETING.ACCEPTED"}]}',
                                                          headers: { 'Content-Type' => 'application/json' })
    clear_enqueued_jobs
    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
    expect(greeting.reload.source_id).to eq('wamid.GREETING.ACCEPTED')
    expect(request).to have_been_requested.once
  ensure
    SendReplyJob.queue_adapter = previous_adapter if previous_adapter
  end

  it 'does not reopen the customer response window using a delayed message or a missing provider timestamp' do
    conversation.messages.incoming.find_each { |message| message.update!(provider_created_at: nil) }
    create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                     message_type: :incoming, provider_created_at: 2.days.ago)
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.OUTSIDE.WINDOW"}]}',
                                                          headers: { 'Content-Type' => 'application/json' })

    SendReplyJob.perform_now(outgoing.id)

    expect(request).not_to have_been_requested
    expect(outgoing.reload.content_attributes.dig('whatsapp_delivery', 'failure_code')).to eq('message_window_closed')
  end

  it 'recovers an abandoned model claim through the scheduled recovery job' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    approve_launch!
    incoming = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                message_type: :incoming, content: 'Hello', provider_created_at: Time.current)
    intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: incoming, enqueue: false).perform
    intent.update!(state: :processing, owner_token: 'abandoned', attempts: 1, lease_expires_at: 1.minute.ago)
    clear_enqueued_jobs

    perform_enqueued_jobs(only: AiLeadEmployee::OrchestrationIntentJob) { Whatsapp::RecoveryJob.perform_now }

    expect(intent.reload).to be_completed
    expect(intent.attempts).to eq(2)
    expect(intent.outbound_message).to be_present
  end

  it 'ends repeated abandoned model work with one local review instead of an unlimited recovery loop' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    approve_launch!
    incoming = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                message_type: :incoming, content: 'Hello', provider_created_at: Time.current)
    intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: incoming, enqueue: false).perform
    intent.update!(state: :processing, owner_token: 'abandoned', attempts: 3, lease_expires_at: 1.minute.ago)

    2.times { AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id) }

    expect(intent.reload).to have_attributes(state: 'failed', failure_class: 'claim_recovery_exhausted', attempts: 3)
    expect(HumanReviewRequest.where(lead_message: incoming, reason: :provider_failed).count).to eq(1)
    expect(conversation.messages.outgoing.count).to eq(0)
  end

  it 'reconciles a late acknowledgement from the original owner and resolves the unknown review' do
    entered = Queue.new
    release = Queue.new
    request = stub_request(:post, provider_url).to_return do
      entered << true
      release.pop
      { status: 200, body: '{"messages":[{"id":"wamid.LATE.ACCEPTED"}]}', headers: { 'Content-Type' => 'application/json' } }
    end
    message_id = outgoing.id
    worker = Thread.new { ActiveRecord::Base.connection_pool.with_connection { SendReplyJob.perform_now(message_id) } }
    Timeout.timeout(10) { entered.pop }
    outgoing.whatsapp_outbound_delivery.update!(lease_expires_at: 1.minute.ago)
    Whatsapp::OutboundRecoveryJob.perform_now
    expect(outgoing.reload.content_attributes.dig('whatsapp_delivery', 'state')).to eq('unknown')
    release << true
    worker.value

    expect(outgoing.reload.source_id).to eq('wamid.LATE.ACCEPTED')
    expect(outgoing.whatsapp_outbound_delivery).to have_attributes(state: 'accepted', failure_code: nil)
    expect(HumanReviewRequest.find_by!(lead_message: outgoing, reason: :delivery_unknown)).to be_resolved
    expect(request).to have_been_requested.once
  ensure
    release << true if release
    worker&.join
  end

  it 'keeps malformed successful provider responses unknown and never retries them automatically' do
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":123}]}',
                                                          headers: { 'Content-Type' => 'application/json' })
    2.times { SendReplyJob.perform_now(outgoing.id) }
    expect(outgoing.reload.source_id).to be_nil
    expect(outgoing.whatsapp_outbound_delivery).to be_unknown
    expect(request).to have_been_requested.once
  end

  it 'cancels an unavailable template durably without repeatedly queuing it' do
    outgoing.update!(additional_attributes: { template_params: { name: 'removed_template', language: 'en_US' } })
    request = stub_request(:post, provider_url)
    SendReplyJob.perform_now(outgoing.id)
    clear_enqueued_jobs
    Whatsapp::OutboundRecoveryJob.perform_now
    expect(outgoing.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'template_unavailable')
    expect(enqueued_jobs.select { |job| job[:job] == SendReplyJob }).to be_empty
    expect(request).not_to have_been_requested
  end

  it 'allows an authorized Inbox retry only after a definite rejection' do
    request = stub_request(:post, provider_url).to_return(
      { status: 400, body: '{"error":{"code":100}}', headers: { 'Content-Type' => 'application/json' } },
      { status: 200, body: '{"messages":[{"id":"wamid.RETRY.ACCEPTED"}]}', headers: { 'Content-Type' => 'application/json' } }
    )
    SendReplyJob.perform_now(outgoing.id)
    perform_enqueued_jobs(only: SendReplyJob) do
      post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages/#{outgoing.id}/retry",
           headers: admin.create_new_auth_token
    end
    expect(response).to have_http_status(:ok)
    expect(outgoing.reload.source_id).to eq('wamid.RETRY.ACCEPTED')
    expect(outgoing.external_error).to be_nil
    expect(request).to have_been_requested.twice
  end

  # The worker reloads persisted Attachments; intercept only their dispatch-time media capability boundary.
  # rubocop:disable RSpec/AnyInstance
  %w[whatsapp_cloud default].each do |provider|
    it "keeps #{provider} local attachment preparation failure retryable without making a provider request" do
      channel.update!(provider: provider)
      attachment = outgoing.attachments.new(account: channel.account, file_type: :image)
      attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      attachment.save!
      # Media capability generation is a local boundary and can fail before any HTTP request.
      allow_any_instance_of(Attachment).to receive(:download_url).and_raise(ActiveSupport::MessageVerifier::InvalidSignature)
      url = provider == 'default' ? 'https://waba.360dialog.io/v1/messages' : provider_url
      request = stub_request(:post, url).to_return(status: 200, body: '{"messages":[{"id":"wamid.MEDIA.RETRY"}]}',
                                                   headers: { 'Content-Type' => 'application/json' })

      SendReplyJob.perform_now(outgoing.id)

      expect(request).not_to have_been_requested
      expect(outgoing.reload.whatsapp_outbound_delivery).to have_attributes(state: 'failed', failure_code: 'preparation_failed',
                                                                            dispatch_started_at: nil)
      expect(HumanReviewRequest.where(lead_message: outgoing, reason: :delivery_unknown)).to be_empty
      allow_any_instance_of(Attachment).to receive(:download_url).and_call_original
      perform_enqueued_jobs(only: SendReplyJob) do
        post "/api/v1/accounts/#{channel.account_id}/conversations/#{conversation.display_id}/messages/#{outgoing.id}/retry",
             headers: admin.create_new_auth_token
      end
      expect(response).to have_http_status(:ok)
      expect(outgoing.reload.source_id).to eq('wamid.MEDIA.RETRY')
      expect(request).to have_been_requested.once
    end
  end

  %w[token_only routing].each do |rotation|
    it "cancels prepared media after a #{rotation} connection change before authorization" do
      attachment = outgoing.attachments.new(account: channel.account, file_type: :image)
      attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      attachment.save!
      entered = Queue.new
      release = Queue.new
      allow_any_instance_of(Attachment).to receive(:download_url).and_wrap_original do |method|
        entered << true
        release.pop
        method.call
      end
      request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.STALE.CONNECTION"}]}',
                                                            headers: { 'Content-Type' => 'application/json' })
      message_id = outgoing.id
      worker = Thread.new { ActiveRecord::Base.connection_pool.with_connection { SendReplyJob.perform_now(message_id) } }
      Timeout.timeout(10) { entered.pop }
      changed = channel.provider_config.merge('api_key' => 'rotated-test-key')
      changed['phone_number_id'] = '987654321' if rotation == 'routing'
      channel.update!(provider_config: changed)
      release << true
      worker.value

      expect(request).not_to have_been_requested
      expect(outgoing.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'connection_changed')
    ensure
      release << true if release
      worker&.join
    end
  end

  # rubocop:enable RSpec/AnyInstance

  %w[membership_removed assignee_changed].each do |change|
    it "rechecks the human sender at the actual dispatch boundary after #{change}" do
      message = outgoing
      membership = AccountUser.find_by!(account: channel.account, user: admin)
      if change == 'membership_removed'
        membership.destroy!
      else
        membership.update!(role: :agent)
        conversation.update_columns(assignee_id: nil) # rubocop:disable Rails/SkipsModelValidations -- Verify final authority without callbacks.
      end
      request = stub_request(:post, provider_url)
      SendReplyJob.perform_now(message.id)
      expect(message.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'sender_access_revoked')
      expect(request).not_to have_been_requested
    end
  end

  it 'cancels a follow-up that was canceled after its outgoing Message was recorded' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    approve_launch!
    follow_up = create(:lead_follow_up, account: channel.account, conversation: conversation, contact: conversation.contact,
                                        scheduled_at: 1.minute.ago)
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform
    message = follow_up.reload.message
    follow_up.cancel!('lead_responded')
    request = stub_request(:post, provider_url)

    AiLeadEmployee::OutboxDispatchJob.perform_now

    expect(message.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'follow_up_canceled')
    expect(request).not_to have_been_requested
  end

  %w[current current_formatted recipient_removed origin_changed].each do |case_name|
    it "checks current Review Request alert authority when #{case_name}" do
      conversation.update!(control_state: :ai_active, assignee: nil)
      approve_launch!
      recipient = case_name == 'current_formatted' ? '+255 700 000 094' : '255700000094'
      channel.account.update!(settings: channel.account.settings.merge('ai_review_alert_recipients' => [recipient]))
      incoming = conversation.messages.incoming.first
      result = AiLeadEmployee::HumanReviewRequestService.new(conversation: conversation, lead_message: incoming,
                                                             reason: :no_approved_knowledge, enqueue_alerts: false).perform
      alert = channel.account.messages.find(result.request.alert_deliveries.sole['message_id'])
      create(:message, account: channel.account, inbox: channel.inbox, conversation: alert.conversation,
                       message_type: :incoming, provider_created_at: Time.current)
      if case_name == 'recipient_removed'
        channel.account.update!(settings: channel.account.settings.merge('ai_review_alert_recipients' => []))
      elsif case_name == 'origin_changed'
        Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin)
      end
      request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.ALERT.ACCEPTED"}]}',
                                                            headers: { 'Content-Type' => 'application/json' })
      SendReplyJob.perform_now(alert.id)
      if case_name.start_with?('current')
        expect(alert.reload.source_id).to eq('wamid.ALERT.ACCEPTED')
        expect(request).to have_been_requested.once
      else
        expect(alert.reload.whatsapp_outbound_delivery).to be_canceled
        expect(request).not_to have_been_requested
      end
    end
  end

  it 'upgrades old outgoing messages without inventing acceptance or replaying uncertain history' do
    uncertain = outgoing
    accepted = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                sender: admin, message_type: :outgoing, content: 'Old accepted message')
    accepted.update!(source_id: 'wamid.LEGACY.ACCEPTED')
    [uncertain, accepted].each do |message|
      message.whatsapp_outbound_delivery.destroy!
      message.update_columns(content_attributes: {}) # rubocop:disable Rails/SkipsModelValidations -- Reproduce legacy persisted evidence.
    end
    require Rails.root.join('db/migrate/20260910000402_backfill_whatsapp_outbound_evidence')
    2.times { BackfillWhatsappOutboundEvidence.new.up }
    clear_enqueued_jobs
    Whatsapp::OutboundRecoveryJob.perform_now

    expect(uncertain.reload.whatsapp_outbound_delivery).to have_attributes(state: 'unknown', failure_code: 'legacy_acceptance_unknown')
    expect(accepted.reload.whatsapp_outbound_delivery).to have_attributes(state: 'accepted', provider_message_id: 'wamid.LEGACY.ACCEPTED')
    expect(HumanReviewRequest.where(lead_message: uncertain, reason: :delivery_unknown).count).to eq(1)
    expect(enqueued_jobs.select { |job| job[:job] == SendReplyJob }).to be_empty
  end

  it 'fails malformed template preparation durably and lets recovery advance to a valid reply' do
    channel.update!(message_templates: [{ 'name' => 'approved', 'language' => 'en_US', 'status' => 'APPROVED', 'components' => [] }])
    outgoing.update!(additional_attributes: { template_params: { name: 'approved', language: 'en_US', processed_params: { footer: 'invalid' } } })
    valid = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                             sender: admin, message_type: :outgoing, content: 'Valid reply')
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.VALID.AFTER.BAD"}]}',
                                                          headers: { 'Content-Type' => 'application/json' })
    expect { SendReplyJob.perform_now(outgoing.id) }.not_to raise_error
    clear_enqueued_jobs
    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
    expect(outgoing.reload.whatsapp_outbound_delivery).to have_attributes(state: 'failed', failure_code: 'preparation_failed')
    expect(valid.reload.source_id).to eq('wamid.VALID.AFTER.BAD')
    expect(request).to have_been_requested.once
  end

  it 'waits for the Channel Greeting acceptance before sending an AI answer from a competing worker' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    approve_launch!
    channel.inbox.update!(greeting_enabled: true, greeting_message: 'Welcome first')
    Whatsapp::ChannelGreetingRecorder.new(conversation.messages.incoming.first).perform
    greeting = conversation.messages.template.sole
    answer = create(:message, :bot_message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                            message_type: :outgoing, content: 'Answer second')
    order = []
    request = stub_request(:post, provider_url).to_return do |http|
      text = JSON.parse(http.body).dig('text', 'body')
      order << text
      SendReplyJob.perform_now(answer.id) if text == 'Welcome first'
      { status: 200, body: { messages: [{ id: "wamid.ORDER.#{order.length}" }] }.to_json, headers: { 'Content-Type' => 'application/json' } }
    end
    SendReplyJob.perform_now(answer.id)
    expect(request).not_to have_been_requested
    SendReplyJob.perform_now(greeting.id)
    clear_enqueued_jobs
    perform_enqueued_jobs(only: SendReplyJob) { Whatsapp::OutboundRecoveryJob.perform_now }
    expect(order).to eq(['Welcome first', 'Answer second'])
    expect(answer.reload.whatsapp_outbound_delivery).to be_accepted
  end

  it 'does not cancel another tenant delivery through tampered origin metadata' do
    other_channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    other_conversation = create(:conversation, account: other_channel.account, inbox: other_channel.inbox)
    other = create(:message, :bot_message, account: other_channel.account, inbox: other_channel.inbox, conversation: other_conversation,
                                           message_type: :outgoing,
                                           additional_attributes: { ai_lead_employee: { origin_conversation_id: conversation.id } })
    Conversations::ControlService.new(conversation: conversation).pause_ai!
    expect(other.reload.whatsapp_outbound_delivery).to be_pending
  end

  it 'allows a fresh answer after resume without reviving a canceled greeting from an earlier control version' do
    conversation.update!(control_state: :ai_active, assignee: nil)
    create(:ai_provider_connection, account: channel.account)
    approve_launch!
    channel.inbox.update!(greeting_enabled: true, greeting_message: 'Old greeting')
    Whatsapp::ChannelGreetingRecorder.new(conversation.messages.incoming.first).perform
    greeting = conversation.messages.template.sole
    Conversations::ControlService.new(conversation: conversation).human_takeover!(operator: admin)
    conversation.update!(assignee: nil)
    Conversations::ControlService.new(conversation: conversation).resume_ai!
    incoming = create(:message, account: channel.account, inbox: channel.inbox, conversation: conversation,
                                message_type: :incoming, content: 'Hello', provider_created_at: Time.current)
    intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: incoming, enqueue: false).perform
    AiLeadEmployee::OrchestrationIntentJob.perform_now(intent.id)
    request = stub_request(:post, provider_url).to_return(status: 200, body: '{"messages":[{"id":"wamid.AFTER.RESUME"}]}',
                                                          headers: { 'Content-Type' => 'application/json' })
    AiLeadEmployee::OutboxDispatchJob.perform_now
    expect(greeting.reload.whatsapp_outbound_delivery).to be_canceled
    expect(intent.reload.outbound_message.source_id).to eq('wamid.AFTER.RESUME')
    expect(request).to have_been_requested.once
  end
end
