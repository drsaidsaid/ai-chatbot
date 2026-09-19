require 'rails_helper'

# Independent workers and PostgreSQL pause gates must remain available to cleanup.
# rubocop:disable RSpec/InstanceVariable
RSpec.describe 'WhatsApp alert authorization and review rejection', type: :request do
  self.use_transactional_tests = false

  before do
    skip 'Dedicated R07 current database and explicit fixture cleanup opt-in required' unless committed_fixture_database?

    clean_committed_fixtures
    @workers = []
    @release = Queue.new
    @channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    @admin = create(:user, :administrator, account: @channel.account)
    @conversation = create(:conversation, account: @channel.account, inbox: @channel.inbox, control_state: :ai_active, assignee: nil)
    incoming = create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                                message_type: :incoming, provider_created_at: Time.current)
    approve_launch!
    @channel.account.update!(settings: @channel.account.settings.merge('ai_review_alert_recipients' => ['255700000094']))
    @review = AiLeadEmployee::HumanReviewRequestService.new(conversation: @conversation, lead_message: incoming,
                                                            reason: :no_approved_knowledge, enqueue_alerts: false).perform.request
    @alert = @channel.account.messages.find(@review.alert_deliveries.sole['message_id'])
    create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @alert.conversation,
                     message_type: :incoming, provider_created_at: Time.current)
    @provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages}).to_return(
      status: 200, body: '{"messages":[{"id":"wamid.ALERT.SERIALIZED"}]}', headers: { 'Content-Type' => 'application/json' }
    )
    @headers = @admin.create_new_auth_token
  end

  after do
    @release << true if @release
    ActiveRecord::Base.connection.execute('SELECT pg_advisory_unlock_all()') if committed_fixture_database?
    Array(@workers).each(&:join)
    next unless committed_fixture_database?

    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r04_pause_alert_authorization ON whatsapp_outbound_deliveries')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r04_pause_alert_authorization()')
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r04_pause_ingress ON messages')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r04_pause_ingress()')
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r04_pause_booking_preparation ON bookings')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r04_pause_booking_preparation()')
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r04_pause_review_insert ON human_review_requests')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r04_pause_review_insert()')
    ActiveRecord::Base.connection.execute('DROP TRIGGER IF EXISTS r04_pause_echo_ingress ON messages')
    ActiveRecord::Base.connection.execute('DROP FUNCTION IF EXISTS r04_pause_echo_ingress()')
    clean_committed_fixtures if committed_fixture_database?
  end

  def clean_committed_fixtures
    raise 'Dedicated R07 current database and explicit fixture cleanup opt-in required' unless committed_fixture_database?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end

  def committed_fixture_database?
    Rails.env.test? && ENV['ALE_R07_CURRENT_DB'] == '1' &&
      ActiveRecord::Base.connection_db_config.database == 'ale_r07_current_20260913_spec'
  end

  def approve_launch!
    connection = @channel.account.ai_provider_connection || create(:ai_provider_connection, account: @channel.account)
    AiLeadEmployee::Evaluation::ScenarioCatalog.required_keys.each do |key|
      create(:ai_lead_employee_evaluation_run, :reviewed_pass, account: @channel.account, user: @admin, scenario_key: key,
                                                               provider_snapshot: { 'provider' => connection.provider, 'model' => connection.model,
                                                                                    'configuration_version' => connection.configuration_version })
    end
    evaluator = AiLeadEmployee::Evaluation::LaunchGateEvaluator.new(account: @channel.account)
    evaluator.update!(team_roleplay_completed: true, pilot_conversations_reviewed_count: 3)
    evaluator.approve!(user: @admin, notes: 'Synthetic R04 concurrency evidence only')
  end

  def start_worker(name)
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        connection.execute("SET application_name = #{connection.quote(name)}")
        yield
      ensure
        connection.execute('RESET application_name')
      end
    end
    @workers << worker
    worker
  end

  def reject_review
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post("/api/v1/accounts/#{@channel.account_id}/human_review_requests/#{@review.id}/reject",
                 headers: @headers, params: { operator_answer: 'No alert is needed.' })
    expect(session.response).to have_http_status(:ok)
  end

  def await_blocked_or_finished(worker, name)
    Timeout.timeout(10) do
      loop do
        return worker.value unless worker.alive?

        blocked = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
          SELECT EXISTS (SELECT 1 FROM pg_stat_activity
          WHERE application_name = '#{name}' AND cardinality(pg_blocking_pids(pid)) > 0)
        SQL
        return if blocked

        sleep 0.01
      end
    end
  end

  def await_blocked!(worker, name)
    Timeout.timeout(10) do
      loop do
        raise "#{name} completed before reaching its PostgreSQL lock wait" unless worker.alive?

        blocked = ActiveRecord::Base.connection.select_value(<<~SQL.squish)
          SELECT EXISTS (SELECT 1 FROM pg_stat_activity
          WHERE application_name = '#{name}' AND cardinality(pg_blocking_pids(pid)) > 0)
        SQL
        return if blocked

        sleep 0.01
      end
    end
  end

  it 'serializes concurrent Review replays into one linked alert Message' do
    lead_message = create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                                    message_type: :incoming, content: 'A second question', provider_created_at: Time.current)
    start = Queue.new
    workers = Array.new(2) do |index|
      start_worker("r14-review-replay-#{index}") do
        start.pop
        AiLeadEmployee::HumanReviewRequestService.new(
          conversation: @conversation, lead_message: lead_message,
          reason: :no_approved_knowledge, enqueue_alerts: false
        ).perform.request.id
      end
    end
    workers.size.times { start << true }
    request_ids = workers.map(&:value)
    request = HumanReviewRequest.find(request_ids.first)
    alert_messages = Message.where("additional_attributes #>> '{ai_lead_employee,review_request_id}' = ?", request.id.to_s)

    expect(request_ids.uniq).to contain_exactly(request.id)
    expect(request.reload.alert_deliveries.one?).to be(true)
    expect(alert_messages.count).to eq(1)
    expect(request.alert_deliveries.sole['message_id']).to eq(alert_messages.sole.id)
  end

  it 'publishes Review dispatch only after its Message link is committed' do
    lead_message = create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                                    message_type: :incoming, content: 'A committed question', provider_created_at: Time.current)
    observed = nil
    allow(SendReplyJob).to receive(:perform_later) do |message_id|
      observed = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          request = HumanReviewRequest.find_by!(lead_message: lead_message, reason: :no_approved_knowledge)
          [Message.exists?(message_id), request.alert_deliveries.sole['message_id']]
        end
      end.value
    end

    result = nil
    ApplicationRecord.transaction do
      result = AiLeadEmployee::HumanReviewRequestService.new(
        conversation: @conversation, lead_message: lead_message, reason: :no_approved_knowledge
      ).perform
    end

    expect(observed).to eq([true, result.request.alert_deliveries.sole['message_id']])
    expect(SendReplyJob).to have_received(:perform_later).once
  end

  it 'drops Review dispatch publication when an enclosing transaction rolls back' do
    lead_message = create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                                    message_type: :incoming, content: 'A rolled back question', provider_created_at: Time.current)
    allow(SendReplyJob).to receive(:perform_later)

    ApplicationRecord.transaction do
      AiLeadEmployee::HumanReviewRequestService.new(
        conversation: @conversation, lead_message: lead_message, reason: :no_approved_knowledge
      ).perform
      raise ActiveRecord::Rollback
    end

    expect(HumanReviewRequest.where(lead_message: lead_message, reason: :no_approved_knowledge)).to be_empty
    expect(Message.where("additional_attributes #>> '{ai_lead_employee,review_request_id}' IS NOT NULL").where.not(id: @alert.id)).to be_empty
    expect(SendReplyJob).not_to have_received(:perform_later)
  end

  it 'restarts knowledge reconciliation when unlocked metadata discovers a new alert Conversation' do
    configure_domain_alert_routes(AiLeadEmployee::KnowledgeApprovalAlertDeliveryService::ALERT_TYPE)
    item = create(:knowledge_item, account: @channel.account, status: :draft, approved_at: nil, metadata: {})
    stale_service = AiLeadEmployee::KnowledgeApprovalAlertDeliveryService.new(knowledge_item: item, enqueue: false)
    first_snapshot = Queue.new
    snapshot_release = Queue.new
    locked_sets = Queue.new
    first_call = true
    allow(stale_service).to receive(:lock_alert_conversations!).and_wrap_original do |method, conversation_ids|
      locked_sets << conversation_ids
      if first_call
        first_call = false
        first_snapshot << true
        snapshot_release.pop
      end
      method.call(conversation_ids)
    end
    stale_worker = start_worker('r14-stale-knowledge-snapshot') { stale_service.perform }
    Timeout.timeout(10) { first_snapshot.pop }
    AiLeadEmployee::KnowledgeApprovalAlertDeliveryService.new(knowledge_item: item.reload, enqueue: false).perform
    alert = Message.find(item.reload.metadata.fetch('knowledge_approval_alert_deliveries').sole.fetch('message_id'))
    snapshot_release << true
    stale_worker.value

    expect([locked_sets.pop, locked_sets.pop]).to eq([[], [alert.conversation_id]])
    expect(Message.where("additional_attributes #>> '{ai_lead_employee,knowledge_item_id}' = ?", item.id.to_s).count).to eq(1)
  ensure
    snapshot_release << true if snapshot_release
  end

  it 'serializes a knowledge retry with dispatch using Conversation then approval authority' do
    configure_domain_alert_routes(AiLeadEmployee::KnowledgeApprovalAlertDeliveryService::ALERT_TYPE)
    item = create(:knowledge_item, account: @channel.account, status: :draft, approved_at: nil, metadata: {})
    AiLeadEmployee::KnowledgeApprovalAlertDeliveryService.new(knowledge_item: item, enqueue: false).perform
    alert = Message.find(item.reload.metadata.fetch('knowledge_approval_alert_deliveries').sole.fetch('message_id'))
    create(:message, account: @channel.account, inbox: @channel.inbox, conversation: alert.conversation,
                     message_type: :incoming, provider_created_at: Time.current)
    alert.update!(status: :failed, external_error: 'retry requested')
    entered = Queue.new
    dispatch_release = Queue.new
    allow_any_instance_of(Whatsapp::OutboundAlertAuthority).to receive(:lock_record!).and_wrap_original do |method| # rubocop:disable RSpec/AnyInstance
      if Thread.current[:r14_pause_knowledge_dispatch]
        entered << true
        dispatch_release.pop
      end
      method.call
    end
    dispatch = start_worker('r14-knowledge-dispatch') do
      Thread.current[:r14_pause_knowledge_dispatch] = true
      SendReplyJob.perform_now(alert.id)
    ensure
      Thread.current[:r14_pause_knowledge_dispatch] = false
    end
    Timeout.timeout(10) { entered.pop }
    retry_worker = start_worker('r14-knowledge-retry') do
      AiLeadEmployee::KnowledgeApprovalAlertDeliveryService.new(knowledge_item: item.reload, enqueue: false).perform
    end
    await_blocked!(retry_worker, 'r14-knowledge-retry')
    dispatch_release << true
    dispatch.value
    retry_worker.value

    expect(alert.reload.whatsapp_outbound_delivery).to be_accepted
    expect(@provider_request).to have_been_requested.once
    expect(Message.where("additional_attributes #>> '{ai_lead_employee,knowledge_item_id}' = ?", item.id.to_s).count).to eq(1)
  ensure
    dispatch_release << true if dispatch_release
  end

  it 'does not discover a newly committed origin review after the authority prefix recorded absence' do
    inserted = Queue.new
    creator = start_worker('r09-late-review-creator') do
      HumanReviewRequest.transaction do
        review = HumanReviewRequest.create!(account: @channel.account, conversation: @conversation, lead_message: @review.lead_message,
                                            reason: :unsupported_media, question: 'Synthetic future origin authority')
        inserted << review.id
        @release.pop
      end
    end
    new_review_id = Timeout.timeout(10) { inserted.pop }
    attributes = @alert.additional_attributes.deep_dup
    attributes.fetch('ai_lead_employee')['review_request_id'] = new_review_id
    @alert.update!(additional_attributes: attributes)
    entered = Queue.new
    prefix_release = Queue.new
    gated = false
    allow(Whatsapp::DeliveryLifecycle).to receive(:with).and_wrap_original do |original, **arguments, &block|
      unless gated
        gated = true
        entered << true
        prefix_release.pop
      end
      original.call(**arguments, &block)
    end
    sender = start_worker('r09-late-review-sender') { SendReplyJob.perform_now(@alert.id) }
    Timeout.timeout(10) { entered.pop }
    @release << true
    creator.value
    prefix_release << true
    sender.value

    expect(@alert.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'alert_authority_unavailable')
    expect(@provider_request).not_to have_been_requested
  ensure
    @release << true
    prefix_release << true if prefix_release
  end

  it 'cancels an alert when the actual rejection API wins before dispatch authorization' do
    rejected = Queue.new
    mutation = start_worker('r04-review-mutation') do
      HumanReviewRequest.transaction do
        reject_review
        rejected << true
        @release.pop
      end
    end
    Timeout.timeout(10) { rejected.pop }
    dispatch = start_worker('r04-alert-dispatch') { SendReplyJob.perform_now(@alert.id) }
    await_blocked_or_finished(dispatch, 'r04-alert-dispatch')

    expect(@provider_request).not_to have_been_requested
    @release << true
    mutation.value
    dispatch.value
    expect(@review.reload).to be_rejected
    expect(@alert.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'alert_authority_unavailable')
    expect(@provider_request).not_to have_been_requested
  end

  it 'serializes the actual rejection API behind an authorization that already holds review authority' do
    connection = ActiveRecord::Base.connection
    connection.execute('SELECT pg_advisory_lock(94021)')
    connection.execute(<<~SQL.squish)
      CREATE FUNCTION r04_pause_alert_authorization() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.state = 'dispatching' THEN PERFORM pg_advisory_xact_lock(94021); END IF; RETURN NEW; END $$;
      CREATE TRIGGER r04_pause_alert_authorization BEFORE UPDATE ON whatsapp_outbound_deliveries
      FOR EACH ROW EXECUTE FUNCTION r04_pause_alert_authorization();
    SQL
    dispatch = start_worker('r04-alert-dispatch') { SendReplyJob.perform_now(@alert.id) }
    await_blocked_or_finished(dispatch, 'r04-alert-dispatch')
    mutation = start_worker('r04-review-mutation') { reject_review }
    await_blocked_or_finished(mutation, 'r04-review-mutation')

    expect(@review.reload).to be_open
    expect(@provider_request).not_to have_been_requested
    connection.execute('SELECT pg_advisory_unlock(94021)')
    dispatch.value
    mutation.value
    expect(@alert.reload.whatsapp_outbound_delivery).to be_accepted
    expect(@review.reload).to be_rejected
    expect(@provider_request).to have_been_requested.once
  end

  it 'preserves a concurrent human rejection when the original provider owner returns late acceptance' do
    entered = Queue.new
    provider_release = Queue.new
    remove_request_stub(@provider_request)
    @provider_request = stub_request(:post, %r{https://graph.facebook.com/v\d+\.\d+/[^/]+/messages}).to_return do
      entered << true
      provider_release.pop
      { status: 200, body: '{"messages":[{"id":"wamid.LATE.REVIEWED"}]}', headers: { 'Content-Type' => 'application/json' } }
    end
    dispatch = start_worker('r04-alert-dispatch') { SendReplyJob.perform_now(@alert.id) }
    Timeout.timeout(10) { entered.pop }
    @alert.whatsapp_outbound_delivery.update!(lease_expires_at: 1.minute.ago)
    Whatsapp::OutboundRecoveryJob.perform_now
    @review = HumanReviewRequest.find_by!(lead_message: @alert, reason: :delivery_unknown)
    rejected = Queue.new
    mutation = start_worker('r04-review-mutation') do
      HumanReviewRequest.transaction do
        reject_review
        rejected << true
        @release.pop
      end
    end
    Timeout.timeout(10) { rejected.pop }
    provider_release << true
    await_blocked_or_finished(dispatch, 'r04-alert-dispatch')
    @release << true
    mutation.value
    dispatch.value

    expect(@alert.reload.whatsapp_outbound_delivery).to be_accepted
    expect(@review.reload).to have_attributes(status: 'rejected', resolution_kind: 'rejected', operator_answer: 'No alert is needed.')
    expect(@provider_request).to have_been_requested.once
  ensure
    provider_release << true if provider_release
  end

  it 'recovers unknown delivery while the actual retry API competes without a lock inversion' do
    @alert.whatsapp_outbound_delivery.update!(state: :dispatching, owner_token: 'interrupted-owner',
                                              lease_expires_at: 1.minute.ago, dispatch_started_at: 2.minutes.ago)
    connection = ActiveRecord::Base.connection
    connection.execute('SELECT pg_advisory_lock(94021)')
    connection.execute(<<~SQL.squish)
      CREATE FUNCTION r04_pause_review_insert() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.reason = 9 THEN PERFORM pg_advisory_xact_lock(94021); END IF; RETURN NEW; END $$;
      CREATE TRIGGER r04_pause_review_insert BEFORE INSERT ON human_review_requests
      FOR EACH ROW EXECUTE FUNCTION r04_pause_review_insert();
    SQL
    recovery = start_worker('r04-alert-recovery') { Whatsapp::OutboundRecoveryJob.perform_now }
    await_blocked_or_finished(recovery, 'r04-alert-recovery')
    retry_request = start_worker('r04-alert-retry') do
      session = ActionDispatch::Integration::Session.new(Rails.application)
      session.post("/api/v1/accounts/#{@channel.account_id}/conversations/#{@alert.conversation.display_id}/messages/#{@alert.id}/retry",
                   headers: @headers)
      session.response.status
    end
    await_blocked_or_finished(retry_request, 'r04-alert-retry')
    connection.execute('SELECT pg_advisory_unlock(94021)')
    recovery.value

    expect(retry_request.value).to eq(409)
    expect(@alert.reload.whatsapp_outbound_delivery).to be_unknown
    expect(HumanReviewRequest.where(lead_message: @alert, reason: :delivery_unknown).count).to eq(1)
    expect(@provider_request).not_to have_been_requested
  end

  %w[booking handoff].each do |kind|
    it "serializes #{kind} cancellation with its canonical pending alert" do
      record = canonical_domain_alert(kind)
      canceled = Queue.new
      mutation = start_worker('r04-domain-mutation') do
        record.class.transaction do
          record.update!(status: :canceled)
          canceled << true
          @release.pop
        end
      end
      Timeout.timeout(10) { canceled.pop }
      dispatch = start_worker('r04-alert-dispatch') { SendReplyJob.perform_now(@alert.id) }
      await_blocked_or_finished(dispatch, 'r04-alert-dispatch')
      expect(@provider_request).not_to have_been_requested
      @release << true
      mutation.value
      dispatch.value
      expect(@alert.reload.whatsapp_outbound_delivery).to have_attributes(state: 'canceled', failure_code: 'alert_authority_unavailable')
      expect(@provider_request).not_to have_been_requested
    end
  end

  %w[dispatch cancel].each do |competitor|
    it "allows booking preparation to finish when #{competitor} competes for its Conversation" do
      booking = canonical_domain_alert('booking')
      booking.update!(provider_event_id: nil, confirmation_message_id: nil)
      connection = ActiveRecord::Base.connection
      connection.execute('SELECT pg_advisory_lock(94021)')
      connection.execute(<<~SQL.squish)
        CREATE FUNCTION r04_pause_booking_preparation() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN IF NEW.provider_event_id IS NOT NULL THEN PERFORM pg_advisory_xact_lock(94021); END IF; RETURN NEW; END $$;
        CREATE TRIGGER r04_pause_booking_preparation BEFORE UPDATE ON bookings
        FOR EACH ROW EXECUTE FUNCTION r04_pause_booking_preparation();
      SQL
      preparation = start_worker('r04-booking-preparation') do
        booking_service_for(booking).perform
      end
      await_blocked_or_finished(preparation, 'r04-booking-preparation')
      contender = start_worker('r04-booking-contender') do
        if competitor == 'dispatch'
          SendReplyJob.perform_now(@alert.id)
        else
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post("/api/v1/accounts/#{@channel.account_id}/bookings/#{booking.id}/cancel",
                       headers: @headers, params: { idempotency_key: 'concurrent-cancel', reason: 'Schedule changed' })
          expect(session.response).to have_http_status(:ok)
        end
      end
      await_blocked_or_finished(contender, 'r04-booking-contender')
      connection.execute('SELECT pg_advisory_unlock(94021)')
      preparation.value
      contender.value
      if competitor == 'dispatch'
        expect(@alert.reload.whatsapp_outbound_delivery).to be_accepted
        expect(@provider_request).to have_been_requested.once
      else
        expect(booking.reload).to be_canceled
        expect(@alert.reload.whatsapp_outbound_delivery).to be_canceled
        expect(@provider_request).not_to have_been_requested
      end
    end
  end

  it 'processes signed ingress alongside dispatch using the same Channel then Conversation lock order' do
    receipt_id = record_signed_ingress
    connection = ActiveRecord::Base.connection
    connection.execute('SELECT pg_advisory_lock(94021)')
    connection.execute(<<~SQL.squish)
      CREATE FUNCTION r04_pause_ingress() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.source_id = 'wamid.AUTH.INGRESS' THEN PERFORM pg_advisory_xact_lock(94021); END IF; RETURN NEW; END $$;
      CREATE TRIGGER r04_pause_ingress BEFORE INSERT ON messages FOR EACH ROW EXECUTE FUNCTION r04_pause_ingress();
    SQL
    ingress = start_worker('r04-ingress') { Webhooks::WhatsappEventsJob.perform_now(receipt_id) }
    await_blocked_or_finished(ingress, 'r04-ingress')
    dispatch = start_worker('r04-alert-dispatch') { SendReplyJob.perform_now(@alert.id) }
    await_blocked_or_finished(dispatch, 'r04-alert-dispatch')
    connection.execute('SELECT pg_advisory_unlock(94021)')
    ingress.value
    dispatch.value

    expect(Whatsapp::WebhookEvent.find_by!(provider_message_id: 'wamid.AUTH.INGRESS')).to be_processed
    expect(@alert.reload.whatsapp_outbound_delivery).to be_accepted
    expect(@provider_request).to have_been_requested.once
  end

  it 'makes queued dispatch observe a direct coexistence-echo takeover before provider authorization' do
    connection = ActiveRecord::Base.connection
    connection.execute('SELECT pg_advisory_lock(94021)')
    connection.execute(<<~SQL.squish)
      CREATE FUNCTION r04_pause_echo_ingress() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN IF NEW.source_id = 'wamid.ECHO.ATOMIC' THEN PERFORM pg_advisory_xact_lock(94021); END IF; RETURN NEW; END $$;
      CREATE TRIGGER r04_pause_echo_ingress BEFORE INSERT ON messages FOR EACH ROW EXECUTE FUNCTION r04_pause_echo_ingress();
    SQL
    echo = start_worker('r07-direct-echo') do
      Whatsapp::IncomingMessageWhatsappCloudService.new(
        inbox: @channel.inbox,
        params: coexistence_echo_payload,
        outgoing_echo: true
      ).perform
    end
    await_blocked!(echo, 'r07-direct-echo')
    dispatch = start_worker('r07-queued-dispatch') { SendReplyJob.perform_now(@alert.id) }
    await_blocked!(dispatch, 'r07-queued-dispatch')
    connection.execute('SELECT pg_advisory_unlock(94021)')
    echo.value
    dispatch.value

    expect(@conversation.reload).to be_human_active
    expect(@alert.reload.whatsapp_outbound_delivery).to be_canceled
    expect(@provider_request).not_to have_been_requested
  end

  def coexistence_echo_payload
    recipient = @conversation.contact_inbox.source_id
    {
      object: 'whatsapp_business_account',
      entry: [{ changes: [{ field: 'smb_message_echoes', value: {
        message_echoes: [{ from: @channel.phone_number.delete_prefix('+'), to: recipient,
                           id: 'wamid.ECHO.ATOMIC', timestamp: Time.current.to_i.to_s,
                           type: 'text', text: { body: 'Handled in WhatsApp.' } }]
      } }] }]
    }.with_indifferent_access
  end

  def record_signed_ingress
    from = @conversation.contact_inbox.source_id
    body = { object: 'whatsapp_business_account', entry: [{ id: @channel.provider_config['business_account_id'], changes: [{
      field: 'messages', value: {
        metadata: { phone_number_id: @channel.provider_config['phone_number_id'], display_phone_number: @channel.phone_number.delete_prefix('+') },
        contacts: [{ wa_id: from, profile: { name: 'Synthetic Lead' } }],
        messages: [{ id: 'wamid.AUTH.INGRESS', from: from, timestamp: Time.current.to_i.to_s, type: 'text', text: { body: 'A new question' } }]
      }
    }] }] }.to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', @channel.signing_secrets.first, body)
    post "/webhooks/whatsapp/#{@channel.phone_number}", params: body, headers: {
      'CONTENT_TYPE' => 'application/json', 'X-Hub-Signature-256' => "sha256=#{signature}"
    }
    expect(response).to have_http_status(:ok)
    response.parsed_body.fetch('receipt_id')
  end

  def configure_domain_alert_routes(type)
    recipient = create(:user, account: @channel.account,
                              custom_attributes: { 'whatsapp_alert_phone' => '255700000094' })
    @channel.account.update!(settings: @channel.account.settings.deep_merge(
      'ai_lead_employee' => {
        'alert_routes' => { type => [{ 'type' => 'whatsapp', 'recipient' => recipient.custom_attributes['whatsapp_alert_phone'] }] }
      }
    ))
  end

  def canonical_domain_alert(kind)
    type = kind == 'booking' ? AiLeadEmployee::BookingService::PREPARATION_ALERT_TYPE : AiLeadEmployee::HighlyQualifiedHandoffService::ALERT_TYPE
    configure_domain_alert_routes(type)
    kind == 'booking' ? canonical_booking_alert : canonical_handoff_alert
  end

  def canonical_booking_alert
    record = create(:booking, account: @channel.account, conversation: @conversation, contact: @conversation.contact,
                              idempotency_key: 'existing-booking')
    record.update!(agreement_message: booking_agreement_message(record))
    create(:google_calendar_connection, account: @channel.account, calendar_id: record.calendar_id)
    stub_google_cancellation
    booking_service_for(record).perform
    @alert = Message.find(record.reload.preparation_alert_deliveries.sole['message_id'])
    record
  end

  def canonical_handoff_alert
    record = create(:lead_handoff, account: @channel.account, conversation: @conversation, contact: @conversation.contact)
    AiLeadEmployee::HandoffAlertDeliveryService.new(handoff: record, alert_text: 'Prepare for this Lead', recipients: ['255700000094'],
                                                    enqueue: false).perform
    @alert = Message.find(record.reload.alert_deliveries.sole['message_id'])
    record
  end

  def booking_agreement_message(booking)
    create(:message, account: @channel.account, inbox: @channel.inbox, conversation: @conversation,
                     sender: @conversation.contact, message_type: :incoming, provider_created_at: booking.starts_at - 1.minute)
  end

  def stub_google_cancellation
    stub_request(:delete, %r{https://www.googleapis.com/calendar/v3/calendars/.*/events/.*}).to_return(status: 204)
  end

  def booking_service_for(booking)
    AiLeadEmployee::BookingService.new(
      conversation: @conversation, qualification: booking.lead_qualification,
      starts_at: booking.starts_at, agreed_starts_at: booking.starts_at,
      agreement_message: booking.agreement_message, idempotency_key: booking.idempotency_key
    )
  end
end
# rubocop:enable RSpec/InstanceVariable
