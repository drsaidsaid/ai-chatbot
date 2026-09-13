# frozen_string_literal: true

require 'rails_helper'
require 'timeout'

RSpec.describe AiLeadEmployee::ReplyUsageReconciler do
  self.use_transactional_tests = false

  let(:workers) { [] }
  let(:release) { Queue.new }

  before { clean_owned_database }

  after do
    4.times { release << true }
    workers.each { |worker| worker.join(15) || worker.kill.join }
    clean_owned_database
  end

  it 'refuses closure after a receipt commits even while usage reconciliation is waiting' do
    usage, message = partial_reply
    projector = receipt_projector(message)
    committed = Queue.new
    allow(projector).to receive(:reconcile_ai_reply_usage).and_wrap_original do |original|
      committed << true
      release.pop
      original.call
    end
    worker, = start_worker { projector.perform }
    Timeout.timeout(10) { committed.pop }

    expect { close(usage) }.to raise_error(ArgumentError, /Canonical sent and terminal failure/)
    release << true
    worker.value

    expect(usage.reload).to be_settled
    expect(usage.released_at).to be_nil
    expect(message.reload.content_attributes['whatsapp_provider_status']).to eq('sent')
  end

  it 'holds receipt evidence until an earlier closure commits and preserves the later receipt' do
    usage, message = partial_reply
    closing = Queue.new
    allow(usage).to receive(:update!).and_wrap_original do |original, attributes|
      result = original.call(attributes)
      if attributes[:status] == :partial_failure_closed
        closing << true
        release.pop
      end
      result
    end
    closer, closer_pid = start_worker { close(usage) }
    Timeout.timeout(10) { closing.pop }
    projector, projector_pid = start_worker { receipt_projector(message).perform }
    Timeout.timeout(10) do
      loop do
        break if blocked_by?(projector_pid, closer_pid) || !projector.alive?

        sleep 0.01
      end
    end
    waited = blocked_by?(projector_pid, closer_pid)
    release << true
    closer.value
    projector.value

    expect(waited).to be(true)
    expect(usage.reload).to have_attributes(status: 'partial_failure_closed', settled_at: nil)
    expect(message.reload.content_attributes['whatsapp_provider_status']).to eq('sent')
    expect(AiLeadEmployee::ReplyAllowance.summary(account: usage.account)).to include(used_ai_replies: 0, remaining_ai_replies: 1)
  end

  def partial_reply
    account = create(:account)
    create(:ai_subscription, account: account, included_ai_replies: 1)
    intent = create(:ai_orchestration_intent, account: account)
    usage = AiLeadEmployee::ReplyAllowance.reserve!(intent: intent)
    messages = Array.new(2) do
      create(:message, account: account, inbox: intent.conversation.inbox, conversation: intent.conversation,
                       message_type: :outgoing, additional_attributes: { ai_lead_employee: { ai_reply_usage_id: usage.id } })
    end
    messages.each do |message|
      Whatsapp::OutboundDelivery.create!(account: account, conversation: intent.conversation, message: message,
                                         ai_reply_usage: usage, observed_control_version: intent.conversation.control_version)
    end
    AiLeadEmployee::ReplyAllowance.register_deliveries!(usage: usage, messages: messages)
    record_partial_receipts(messages)
    expect(usage.reload).to be_partially_delivered
    [usage, messages.last]
  end

  def record_partial_receipts(messages)
    messages.each_with_index do |message, index|
      message.whatsapp_outbound_delivery.update!(state: :accepted, accepted_at: Time.current, provider_message_id: "wamid.order.#{index}")
      Whatsapp::MessageStatusProjector.new(
        message: message.reload, status: { status: index.zero? ? 'sent' : 'failed', timestamp: Time.current.to_i.to_s }
      ).perform
    end
  end

  def receipt_projector(message)
    Whatsapp::MessageStatusProjector.new(message: message.reload,
                                         status: { status: 'sent', timestamp: 5.minutes.from_now.to_i.to_s })
  end

  def close(usage)
    AiLeadEmployee::ReplyAllowance.reconcile!(usage: usage, outcome: 'confirmed_partial_failure',
                                              platform_app: create(:platform_app, finance_operations_enabled: true), reason: 'provider_lookup')
  end

  def start_worker
    pid = Queue.new
    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        pid << connection.select_value('SELECT pg_backend_pid()').to_i
        yield
      end
    end
    workers << worker
    [worker, Timeout.timeout(10) { pid.pop }]
  end

  def blocked_by?(waiting, blocking)
    ActiveRecord::Base.connection.select_value("SELECT #{Integer(blocking)} = ANY(pg_blocking_pids(#{Integer(waiting)}))")
  end

  def clean_owned_database
    connection = ActiveRecord::Base.connection
    unless connection.current_database == 'ale_r23_combined_20260913_spec' && ENV['R23_COMMITTED_FIXTURES'] == 'yes'
      raise 'Committed fixtures require the dedicated R23 integration database and explicit opt-in'
    end

    tables = connection.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end
end
