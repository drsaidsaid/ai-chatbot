# Audit-only reproductions. Loads exact copied release-candidate classes, never Rails.
# No application environment, credentials, database, queues or external services.
require 'active_support/all'
require 'uri'
require 'json'
require 'ostruct'
require 'minitest/autorun'
require 'timeout'

module AiLeadEmployee
  module Orchestration; end
end
module Webhooks; end
module ActionController
  class API
    def self.before_action(*); end
  end
end
class ApplicationJob
  def self.queue_as(*); end
  def self.retry_on(*); end
end
module Whatsapp
  module IncomingMessageServiceHelpers; end
  module IncomingMessageIdentifierHelper; end
end
class Class
  def pattr_initialize(*); end
  def prepend_mod_with(*); end
end

def source(path)
  load File.join(__dir__, 'source', path)
end
source('app/services/ai_lead_employee/qualification_evidence_extractor.rb')
source('app/services/ai_lead_employee/qualification_budget_classifier.rb')
source('app/services/ai_lead_employee/qualification_service.rb')
source('app/services/ai_lead_employee/language_detector.rb')
source('app/services/ai_lead_employee/opt_out_service.rb')
source('app/services/ai_lead_employee/follow_up_delivery_service.rb')
source('app/services/ai_lead_employee/orchestration/decision_placeholder.rb')
source('app/jobs/ai_lead_employee/outbox_dispatch_job.rb')
source('app/controllers/concerns/meta_token_verify_concern.rb')
source('app/controllers/webhooks/whatsapp_controller.rb')
source('app/services/whatsapp/incoming_message_base_service.rb')

OBSERVATIONS = []
def observe(name, facts)
  OBSERVATIONS << { name: name, facts: facts }
end

class MemoryEvent
  attr_reader :payload, :attempts, :state, :account
  def initialize
    @lock = Mutex.new
    @payload = { 'message_id' => 1 }
    @attempts = 0
    @state = :pending
    message = OpenStruct.new(failed?: false, control_state: 'human_active')
    messages = Object.new
    messages.define_singleton_method(:find) { |_id| message }
    @account = OpenStruct.new(messages: messages)
  end
  def pending? = @state == :pending
  def with_lock(&block) = @lock.synchronize(&block)
  def update!(attributes)
    attributes.each { |key, value| instance_variable_set("@#{key}", value) }
  end
  alias update_columns update!
end

class SendReplyJob
  class << self
    attr_accessor :started, :release
    def perform_now(message_id)
      started << message_id
      release.pop if release
    end
  end
end

class OfflineReproductions < Minitest::Test
  def test_manual_cloud_configuration_skips_signature_even_with_global_secret_design
    controller = Webhooks::WhatsappController.new
    channel = OpenStruct.new(provider: 'whatsapp_cloud', provider_config: {})
    controller.define_singleton_method(:whatsapp_channel) { channel }
    controller.define_singleton_method(:channel_meta_app_secrets) { |_channel| [] }
    required = controller.send(:meta_signature_verification_required?)
    assert_equal false, required
    observe('manual_cloud_without_channel_secret', signature_verification_required: required)
  end

  def test_negative_english_statement_becomes_highly_qualified
    text = 'I do not need help now. I am not the decision maker. My budget is $500.'
    values = AiLeadEmployee::QualificationEvidenceExtractor.new(text).evidence
    snapshot = values.transform_values { |value| { 'value' => value } }
    account = OpenStruct.new(qualification_budget_ranges: OpenStruct.new(enabled_in_order: []))
    service = AiLeadEmployee::QualificationService.allocate
    service.instance_variable_set(:@account, account)
    score = service.send(:score_for, snapshot)
    quality = service.send(:quality_for, snapshot, [], score)
    assert_equal :highly_qualified, quality
    assert_equal 'decision maker', values['decision_authority']
    observe('negated_buying_evidence', input: text, evidence: values, score: score, quality: quality)
  end

  def test_swahili_buying_intent_and_tzs_amount_are_missed
    text = 'Nataka kujiunga leo, nina bajeti ya TZS 150,000 na nitalipa mwenyewe.'
    values = AiLeadEmployee::QualificationEvidenceExtractor.new(text).evidence
    assert_equal({}, values)
    assert_equal :swahili, AiLeadEmployee::LanguageDetector.detect(text)
    observe('swahili_tzs_intent', input: text, language: 'swahili', extracted_evidence: values)
  end

  def test_compact_thousands_budget_is_misread
    account = OpenStruct.new(qualification_budget_ranges: OpenStruct.new(enabled_in_order: []))
    service = AiLeadEmployee::QualificationBudgetClassifier.new(account: account, budget_value: '50k')
    cents = service.send(:budget_cents)
    assert_equal 5_000, cents
    assert_equal true, service.out_of_range?
    observe('compact_thousands_budget', input: '50k', parsed_cents: cents, out_of_range: service.out_of_range?)
  end

  def test_opt_out_parser_does_not_recognize_polite_or_alternate_swahili_stop
    results = ['STOP', 'Please stop messaging me', 'acha kunitumia', 'Tafadhali usinitumie ujumbe tena'].to_h do |text|
      service = AiLeadEmployee::OptOutService.new(conversation: nil, message: OpenStruct.new(content: text))
      [text, service.opt_out_message?]
    end
    assert_equal [true, false, true, false], results.values
    observe('opt_out_language_coverage', results)
  end

  def test_ordinary_ai_outbox_dispatch_runs_after_takeover
    event = MemoryEvent.new
    SendReplyJob.started = Queue.new
    SendReplyJob.release = nil
    job = AiLeadEmployee::OutboxDispatchJob.new
    job.send(:dispatch, event)
    assert_equal 1, SendReplyJob.started.size
    assert_equal :delivered, event.state
    observe('dispatch_without_final_ai_control_check', human_active: true, simulated_sender_calls: 1, outbox_state: event.state)
  end

  def test_two_workers_dispatch_same_pending_event
    event = MemoryEvent.new
    SendReplyJob.started = Queue.new
    SendReplyJob.release = Queue.new
    workers = 2.times.map { Thread.new { AiLeadEmployee::OutboxDispatchJob.new.send(:dispatch, event) } }
    starts = Timeout.timeout(3) { 2.times.map { SendReplyJob.started.pop } }
    2.times { SendReplyJob.release << true }
    workers.each(&:join)
    assert_equal [1, 1], starts
    assert_equal 2, event.attempts
    observe('concurrent_dispatch_claim', same_message_sender_calls: starts.size, attempts: event.attempts)
  ensure
    workers&.each { |thread| thread.kill if thread.alive? }
    SendReplyJob.release = nil
  end

  def test_status_batches_use_only_first_and_late_sent_regresses_read
    message = OpenStruct.new(status: 'read')
    message.define_singleton_method(:save!) { true }
    service = Whatsapp::IncomingMessageBaseService.new
    seen = []
    service.instance_variable_set(:@processed_params, statuses: [{ id: 'a', status: 'sent' }, { id: 'b', status: 'delivered' }])
    service.define_singleton_method(:find_message_by_source_id) do |id|
      seen << id
      @message = message
    end
    service.define_singleton_method(:update_whatsapp_identifiers_from_status) { |_status| }
    service.send(:process_statuses)
    assert_equal ['a'], seen
    assert_equal 'sent', message.status
    observe('status_batch_and_order', processed_message_ids: seen, before_status: 'read', after_status: message.status)
  end
end

Minitest.after_run do
  path = File.join(__dir__, 'offline-observations.json')
  File.write(path, JSON.pretty_generate({ ruby: RUBY_VERSION, active_support: ActiveSupport::VERSION::STRING,
    isolation: 'Actual copied methods with in-memory doubles; no Rails boot, database, network, workers or provider calls.',
    observations: OBSERVATIONS.sort_by { |row| row[:name] } }) + "\n")
end
