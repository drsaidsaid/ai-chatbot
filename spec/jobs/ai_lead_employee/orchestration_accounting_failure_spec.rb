# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI orchestration after uncertain provider accounting', type: :job do
  self.use_transactional_tests = false

  before { clean_committed_fixtures }
  after { clean_committed_fixtures }

  it 'never calls the provider again after its response cannot be recorded', :aggregate_failures do
    records = create_orchestration_records
    completion_failure_stubbed = false
    allow(AiLeadEmployee::AiProviderUsage).to receive(:find).and_call_original
    provider_request = stub_provider_success(records) do
      unless completion_failure_stubbed
        completion_failure_stubbed = true
        fail_completion_write!(records.fetch(:connection).usages.sole)
      end
    end

    first_error = run_and_recover(records)

    expect_terminal_uncertainty(records, provider_request, first_error)
  end

  it 'never retries after an unexpected response-processing failure', :aggregate_failures do
    records = create_orchestration_records
    adapter = AiLeadEmployee::AiProvider::OpenRouterAdapter.new(connection: records.fetch(:connection))
    allow(adapter).to receive(:parse_response).and_raise(StandardError, 'synthetic response-processing failure')
    allow(AiLeadEmployee::AiProvider::OpenRouterAdapter).to receive(:new).and_return(adapter)
    provider_request = stub_provider_success(records)

    first_error = run_and_recover(records)

    expect_terminal_uncertainty(records, provider_request, first_error)
  end

  private

  def expect_terminal_uncertainty(records, provider_request, first_error)
    expect(first_error).to be_nil
    expect(provider_request).to have_been_requested.once
    expect_terminal_intent(records)
    expect_no_provider_output(records)
  end

  def expect_terminal_intent(records)
    expect(records.fetch(:intent).reload).to have_attributes(
      state: 'blocked',
      blocked_reason: 'provider_failure',
      failure_class: 'provider_accounting_uncertain'
    )
  end

  def expect_no_provider_output(records)
    expect(records.fetch(:conversation).messages.outgoing).to be_empty
    expect(OutboxEvent.where(account: records.fetch(:account))).to be_empty
    expect(records.fetch(:connection).usages.sole).to have_attributes(status: 'reserved')
  end

  def run_and_recover(records)
    first_error = begin
      AiLeadEmployee::OrchestrationIntentJob.perform_now(records.fetch(:intent).id)
      nil
    rescue StandardError => e
      e
    end
    records.fetch(:intent).update!(lease_expires_at: 1.minute.ago) if records.fetch(:intent).reload.processing?
    perform_enqueued_jobs(only: AiLeadEmployee::OrchestrationIntentJob) { Whatsapp::RecoveryJob.perform_now }
    first_error
  end

  def stub_provider_success(records, &before_response)
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return do
      before_response&.call
      {
        status: 200,
        body: {
          id: 'provider-accounting-uncertain',
          model: records.fetch(:connection).model,
          choices: [{ message: { content: 'Yes, we build AI employees.' }, finish_reason: 'stop' }]
        }.to_json
      }
    end
  end

  def create_orchestration_records
    channel = create(:channel_whatsapp, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    account = channel.account
    connection = create(:ai_provider_connection, account: account, daily_request_limit: 10)
    conversation = create_conversation(channel, account)
    message = create_triggering_message(conversation, channel, account)
    create(:knowledge_item, account: account, question: message.content, answer: 'Yes, we build AI employees.')
    allow(AiLeadEmployee::LaunchGate).to receive(:live_ai_enabled?).with(account).and_return(true)
    intent = AiLeadEmployee::OrchestrationIntentRecorder.new(message: message, enqueue: false).perform
    allow(SendReplyJob).to receive(:perform_later)
    allow(AiLeadEmployee::OutboxDispatchJob).to receive(:perform_later)

    { account: account, connection: connection, conversation: conversation, intent: intent }
  end

  def create_conversation(channel, account)
    contact = create(:contact, account: account, phone_number: '+255700111232')
    contact_inbox = create(:contact_inbox, contact: contact, inbox: channel.inbox, source_id: '255700111232')
    create(
      :conversation,
      account: account,
      inbox: channel.inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      control_state: :ai_active,
      assignee: nil,
      status: :open
    )
  end

  def create_triggering_message(conversation, channel, account)
    create(
      :message,
      account: account,
      inbox: channel.inbox,
      conversation: conversation,
      sender: conversation.contact,
      message_type: :incoming,
      content: 'Do you offer AI employees?',
      source_id: 'wamid.ACCOUNTING.FAILURE'
    )
  end

  def fail_completion_write!(usage)
    allow(AiLeadEmployee::AiProviderUsage).to receive(:find).with(usage.id).and_return(usage)
    allow(usage).to receive(:update!).and_raise(
      ActiveRecord::StatementInvalid,
      'synthetic completion write failure'
    )
  end

  def clean_committed_fixtures
    raise 'Rails test database required' unless Rails.env.test?

    database = ActiveRecord::Base.connection
    tables = database.tables - %w[schema_migrations ar_internal_metadata installation_configs]
    database.execute("TRUNCATE #{tables.map { |table| database.quote_table_name(table) }.join(', ')} CASCADE")
    clear_enqueued_jobs
  end
end
