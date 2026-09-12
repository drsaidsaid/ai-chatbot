# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::FollowUpDeliveryService do
  self.use_transactional_tests = false

  let(:account) { create(:account) }
  let(:channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:conversation) { create(:conversation, account: account, inbox: channel.inbox, control_state: :ai_active, control_version: 4) }
  let(:qualification) { create(:lead_qualification, account: account, contact: conversation.contact, quality: :low_qualified) }
  let(:follow_up) do
    create(:lead_follow_up, account: account, contact: conversation.contact, conversation: conversation,
                            lead_qualification: qualification, control_version: 4, scheduled_at: 1.minute.ago)
  end
  let(:database) { ActiveRecord::Base.connection }

  before { clean_committed_fixtures }

  after do
    database.execute('ALTER TABLE outbox_events DROP CONSTRAINT IF EXISTS r09_reject_follow_up_event')
    clean_committed_fixtures
  end

  %w[control opt_out internal_note].each do |reason|
    it "commits #{reason} cancellation and blocked Attempt state before returning without a send" do
      expected_reason = prepare_cancellation(reason)
      artifact = follow_up
      clear_enqueued_jobs

      expect(described_class.new(follow_up: artifact).perform).to be_nil

      expect(artifact.reload).to have_attributes(status: 'cancelled', cancellation_reason: expected_reason)
      expect(artifact.follow_up_attempt.reload).to be_blocked
      verify_no_publication(artifact)
    end
  end

  it 'keeps an already-cancelled artifact and Attempt unchanged on the pending-state early exit' do
    artifact = follow_up
    artifact.cancel!('operator_cancelled')
    original = artifact.reload.attributes
    original_attempt = artifact.follow_up_attempt.reload.attributes
    clear_enqueued_jobs

    expect(described_class.new(follow_up: artifact).perform).to be_nil

    expect(artifact.reload.attributes).to eq(original)
    expect(artifact.follow_up_attempt.reload.attributes).to eq(original_attempt)
    verify_no_publication(artifact)
  end

  it 'keeps an admitted Attempt and pending artifact unchanged on the replaceability early exit' do
    artifact = follow_up
    artifact.follow_up_attempt.update!(admission_state: :admitted, admitted_at: Time.current)
    original = artifact.reload.attributes
    original_attempt = artifact.follow_up_attempt.reload.attributes
    clear_enqueued_jobs

    expect(described_class.new(follow_up: artifact).perform).to be_nil

    expect(artifact.reload.attributes).to eq(original)
    expect(artifact.follow_up_attempt.reload.attributes).to eq(original_attempt)
    verify_no_publication(artifact)
  end

  it 'reschedules exactly once without consuming its Attempt or publishing a message' do
    artifact = follow_up
    artifact.update!(scheduled_at: 1.hour.from_now)
    clear_enqueued_jobs

    expect do
      expect(described_class.new(follow_up: artifact).perform).to be_nil
    end.to have_enqueued_job(AiLeadEmployee::FollowUpDeliveryJob).exactly(:once)

    expect(artifact.reload).to be_pending
    expect(artifact.follow_up_attempt.reload).to be_unadmitted
    verify_no_publication(artifact)
  end

  it 'rolls back the materialized Message and artifact link when the real outbox insert raises' do
    artifact = follow_up
    original_messages = Message.where(conversation: conversation).count
    original_events = OutboxEvent.count
    clear_enqueued_jobs
    database.execute("ALTER TABLE outbox_events ADD CONSTRAINT r09_reject_follow_up_event CHECK (event_type <> 'ai_employee.follow_up_recorded')")

    expect do
      described_class.new(follow_up: artifact).perform
    end.to raise_error(ActiveRecord::StatementInvalid, /r09_reject_follow_up_event/)

    expect(Message.where(conversation: conversation).count).to eq(original_messages)
    expect(OutboxEvent.count).to eq(original_events)
    expect(artifact.reload).to have_attributes(status: 'pending', message_id: nil)
    expect(artifact.follow_up_attempt.reload).to be_unadmitted
    verify_no_publication(artifact)
  end

  it 'publishes the dispatch job only after the Message, artifact link and outbox event are committed' do
    artifact = follow_up
    observed = nil
    clear_enqueued_jobs
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later).and_wrap_original do |method, event_id|
      observed = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          event = OutboxEvent.find_by(id: event_id)
          [event&.aggregate_id, LeadFollowUp.find(artifact.id).message_id]
        end
      end.value
      method.call(event_id)
    end

    described_class.new(follow_up: artifact).perform

    expect(artifact.reload.message_id).to be_present
    expect(observed).to eq([artifact.message_id, artifact.message_id])
    expect(AiLeadEmployee::OutboxDispatchJob).to have_been_enqueued.exactly(:once)
    expect(WebMock).not_to have_requested(:post, %r{https://graph.facebook.com/})
  end

  def prepare_cancellation(reason)
    case reason
    when 'control'
      conversation.update!(control_state: :human_active, control_version: 5)
      'incompatible_control_state'
    when 'opt_out'
      create(:lead_follow_up_opt_out, account: account, contact: conversation.contact, conversation: conversation)
      'follow_up_opted_out'
    when 'internal_note'
      note = create(:message, account: account, inbox: channel.inbox, conversation: conversation, message_type: :outgoing, private: true)
      follow_up.update!(message: note)
      'internal_note'
    end
  end

  def verify_no_publication(artifact)
    expect(Message.outgoing.where(conversation: conversation, private: false)).to be_empty
    expect(OutboxEvent.where(idempotency_key: "ai-follow-up/#{artifact.id}")).to be_empty
    expect(AiLeadEmployee::OutboxDispatchJob).not_to have_been_enqueued
    expect(WebMock).not_to have_requested(:post, %r{https://graph.facebook.com/})
  end

  def clean_committed_fixtures
    raise 'Dedicated Rails test database required' unless Rails.env.test? && database.current_database == 'ale_r09_offers_20260911_spec'

    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end
end
