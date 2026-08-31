# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
class AiLeadEmployee::Evaluation::SandboxRunner
  PROMPT_VERSION = 'ai-orchestration-v1'

  Result = Struct.new(:run, keyword_init: true)

  def initialize(account:, user:, scenario_key:)
    @account = account
    @user = user
    @scenario = AiLeadEmployee::Evaluation::ScenarioCatalog.find!(scenario_key)
    @simulation_identifier = "evaluation-#{scenario[:key]}-#{SecureRandom.hex(6)}"
  end

  def perform
    simulation = simulate_with_rollback
    Result.new(run: create_run!(simulation))
  rescue StandardError => e
    Result.new(run: failed_run(e))
  end

  private

  attr_reader :account, :user, :scenario, :simulation_identifier

  def simulate_with_rollback
    result = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      context = sandbox_context
      processed_event_ids = Set.new
      steps = scenario[:messages].each_with_index.map do |message_payload, index|
        simulate_step(context, message_payload.with_indifferent_access, index, processed_event_ids)
      end
      result = { status: :completed, steps: steps, metrics: metrics_for(steps), provider_snapshot: provider_snapshot_for(steps) }
      raise ActiveRecord::Rollback
    end
    result
  end

  def simulate_step(context, message_payload, index, processed_event_ids)
    event_id = message_payload[:event_id].presence || "#{simulation_identifier}-#{index}"
    return duplicate_step(index, event_id, message_payload) if processed_event_ids.include?(event_id)

    processed_event_ids << event_id
    incoming_message = create_incoming_message!(context, message_payload, event_id)
    return unsupported_media_step(index, event_id, message_payload, incoming_message) unless text_message?(message_payload)
    return opt_out_step(index, event_id, message_payload, context, incoming_message) if opt_out?(context[:conversation], incoming_message)

    intent = create_intent!(context[:conversation], incoming_message)
    mutate_before_processing!(context[:conversation], intent, message_payload)
    processed_intent = AiLeadEmployee::Orchestration::IntentProcessor.new(
      intent: intent,
      enqueue_deliveries: false,
      enforce_launch_gate: false
    ).perform
    finalize_step(step_payload(index, event_id, message_payload, processed_intent))
  end

  def sandbox_context
    inbox = whatsapp_inbox || create_sandbox_inbox!
    contact = Contact.create!(
      account: account,
      name: "Evaluation Lead #{scenario[:key].humanize}",
      phone_number: "+#{simulation_source_id}",
      email: "#{simulation_identifier}@example.test",
      additional_attributes: { 'evaluation_sandbox' => true }
    )
    contact_inbox = ContactInbox.create!(inbox: inbox, contact: contact, source_id: simulation_source_id)
    conversation = Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      status: :open,
      control_state: :ai_active,
      additional_attributes: { 'evaluation_sandbox' => true, 'simulation_identifier' => simulation_identifier },
      last_activity_at: Time.current
    )
    { inbox: inbox, contact: contact, contact_inbox: contact_inbox, conversation: conversation }
  end

  def whatsapp_inbox
    account.inboxes.to_a.find { |inbox| inbox.channel.is_a?(Channel::Whatsapp) }
  end

  def create_sandbox_inbox!
    channel = Channel::Whatsapp.new(
      account: account,
      phone_number: "+1555#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}",
      provider: 'whatsapp_cloud',
      provider_config: { 'phone_number_id' => "sandbox-#{SecureRandom.hex(4)}", 'source' => 'embedded_signup' }
    )
    channel.save!(validate: false)
    Inbox.create!(account: account, channel: channel, name: 'Evaluation Sandbox', timezone: 'UTC')
  end

  def create_incoming_message!(context, message_payload, event_id)
    Message.create!(
      account: account,
      inbox: context[:inbox],
      conversation: context[:conversation],
      sender: context[:contact],
      message_type: :incoming,
      content_type: :text,
      content: incoming_content(message_payload),
      content_attributes: text_message?(message_payload) ? {} : { is_unsupported: true },
      source_id: event_id,
      created_at: Time.current
    )
  end

  def create_intent!(conversation, incoming_message)
    AiLeadEmployee::OrchestrationIntent.create!(
      account: account,
      conversation: conversation,
      triggering_message: incoming_message,
      observed_control_version: conversation.control_version,
      idempotency_key: "ai-evaluation/#{account.id}/#{simulation_identifier}/#{incoming_message.source_id}/#{conversation.control_version}"
    )
  end

  def mutate_before_processing!(conversation, intent, message_payload)
    conversation.update!(control_version: conversation.control_version + 1) if message_payload[:stale_before_ai]
    conversation.update!(control_state: :human_active) if message_payload[:takeover_before_ai]
    create_coexistence_echo!(conversation) if message_payload[:coexistence_echo_before_ai]
    tenant_mismatch!(intent) if message_payload[:tenant_mismatch_before_ai]
    create_booking_conflict!(conversation) if message_payload[:force_booking_conflict]
  end

  def create_coexistence_echo!(conversation)
    conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: 'Human replied from WhatsApp Business.',
      private: false,
      content_attributes: { external_echo: true }
    )
  end

  def tenant_mismatch!(intent)
    other_account = Account.create!(name: 'Evaluation Other Business Account')
    other_contact = Contact.create!(account: other_account, name: 'Other Lead')
    other_channel = Channel::Api.create!(account: other_account, additional_attributes: {})
    other_inbox = Inbox.create!(account: other_account, channel: other_channel, name: 'Other Inbox')
    other_contact_inbox = ContactInbox.create!(inbox: other_inbox, contact: other_contact, source_id: "tenant-#{simulation_identifier}")
    other_conversation = Conversation.create!(
      account: other_account,
      inbox: other_inbox,
      contact: other_contact,
      contact_inbox: other_contact_inbox
    )
    other_message = Message.create!(
      account: other_account,
      inbox: other_inbox,
      conversation: other_conversation,
      sender: other_contact,
      message_type: :incoming,
      content: 'Wrong tenant'
    )
    # The tenant-isolation scenario intentionally corrupts the FK relation to
    # prove the processor blocks cross-account records before delivery.
    # rubocop:disable Rails/SkipsModelValidations
    intent.update_columns(triggering_message_id: other_message.id)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def create_booking_conflict!(conversation)
    busy_slots = (0...7).map do |offset|
      date = Time.current.utc.to_date + offset.days
      {
        'start' => Time.utc(date.year, date.month, date.day, 9).iso8601,
        'end' => Time.utc(date.year, date.month, date.day, 10).iso8601
      }
    end
    account.update!(
      settings: account.settings.to_h.deep_merge(
        'ai_lead_employee' => {
          'booking' => {
            'connected' => true,
            'minimum_notice_minutes' => 0,
            'working_days' => (0..6).to_a,
            'allowed_hours' => { 'start' => '09:00', 'end' => '10:00' },
            'busy_slots' => busy_slots
          }
        }
      )
    )
    LeadQualification.find_or_create_by!(account: account, contact: conversation.contact) do |record|
      record.quality = :highly_qualified
      record.follow_up_state = :human_review
      record.score = 80
      record.reasons = []
      record.missing_signals = []
      record.evidence_snapshot = {}
      record.last_evaluated_at = Time.current
    end
  end

  def step_payload(index, event_id, message_payload, intent)
    qualification = LeadQualification.find_by(account: account, contact: intent.conversation.contact)
    {
      'index' => index + 1,
      'event_id' => event_id,
      'message_type' => message_payload[:type].presence || 'text',
      'lead_message' => message_payload[:body],
      'expected' => message_payload.fetch(:expected, {}).to_h.stringify_keys,
      'selected_answer' => selected_answer(intent),
      'source_references' => intent.source_references,
      'evidence' => evidence_payload(intent.conversation),
      'qualification' => qualification_payload(qualification),
      'next_question' => intent.decision.dig('qualification', 'next_question'),
      'review_request' => review_request_payload(intent.review_request),
      'review_request_reason' => intent.review_request&.reason,
      'handoff_decision' => handoff_decision(intent, qualification),
      'booking_decision' => booking_decision(intent, qualification),
      'follow_up_decision' => follow_up_decision(intent, qualification),
      'blocked_reason' => intent.blocked_reason,
      'duplicate_ignored' => false,
      'opt_out_recorded' => false,
      'sender_invoked' => false,
      'configuration_version' => qualification&.configuration_version || configuration_version,
      'knowledge_versions' => knowledge_snapshot['items'],
      'provider_model' => intent.model || provider_snapshot['model'],
      'prompt_version' => PROMPT_VERSION
    }
  end

  def selected_answer(intent)
    return intent.outbound_message.content if intent.outbound_message.present?
    return nil if intent.blocked?

    intent.decision['status']
  end

  def unsupported_media_step(index, event_id, message_payload, incoming_message)
    result = AiLeadEmployee::HumanReviewRequestService.new(
      conversation: incoming_message.conversation,
      lead_message: incoming_message,
      reason: 'unsupported_media',
      enqueue_alerts: false
    ).perform
    finalize_step(base_step(index, event_id, message_payload).merge(
                    'selected_answer' => nil,
                    'source_references' => [],
                    'evidence' => [],
                    'qualification' => nil,
                    'next_question' => nil,
                    'review_request' => review_request_payload(result.request),
                    'review_request_reason' => result.request.reason,
                    'handoff_decision' => 'not_evaluated',
                    'booking_decision' => 'not_evaluated',
                    'follow_up_decision' => 'not_evaluated',
                    'blocked_reason' => nil,
                    'duplicate_ignored' => false,
                    'opt_out_recorded' => false,
                    'sender_invoked' => false,
                    'configuration_version' => configuration_version,
                    'knowledge_versions' => knowledge_snapshot['items'],
                    'provider_model' => provider_snapshot['model'],
                    'prompt_version' => PROMPT_VERSION
                  ))
  end

  def opt_out_step(index, event_id, message_payload, context, incoming_message)
    qualification = AiLeadEmployee::QualificationService.new(conversation: context[:conversation],
                                                             incoming_message: incoming_message).perform.qualification
    finalize_step(base_step(index, event_id, message_payload).merge(
                    'selected_answer' => nil,
                    'source_references' => [],
                    'evidence' => evidence_payload(context[:conversation]),
                    'qualification' => qualification_payload(qualification),
                    'next_question' => nil,
                    'review_request' => nil,
                    'review_request_reason' => nil,
                    'handoff_decision' => 'stopped',
                    'booking_decision' => 'not_eligible',
                    'follow_up_decision' => 'opted_out',
                    'blocked_reason' => nil,
                    'duplicate_ignored' => false,
                    'opt_out_recorded' => true,
                    'sender_invoked' => false,
                    'configuration_version' => qualification.configuration_version,
                    'knowledge_versions' => knowledge_snapshot['items'],
                    'provider_model' => provider_snapshot['model'],
                    'prompt_version' => PROMPT_VERSION
                  ))
  end

  def duplicate_step(index, event_id, message_payload)
    finalize_step(base_step(index, event_id, message_payload).merge(
                    'selected_answer' => nil,
                    'source_references' => [],
                    'evidence' => [],
                    'qualification' => nil,
                    'next_question' => nil,
                    'review_request' => nil,
                    'review_request_reason' => nil,
                    'handoff_decision' => 'not_evaluated',
                    'booking_decision' => 'not_evaluated',
                    'follow_up_decision' => 'not_evaluated',
                    'blocked_reason' => nil,
                    'duplicate_ignored' => true,
                    'opt_out_recorded' => false,
                    'sender_invoked' => false,
                    'configuration_version' => configuration_version,
                    'knowledge_versions' => knowledge_snapshot['items'],
                    'provider_model' => provider_snapshot['model'],
                    'prompt_version' => PROMPT_VERSION
                  ))
  end

  def base_step(index, event_id, message_payload)
    {
      'index' => index + 1,
      'event_id' => event_id,
      'message_type' => message_payload[:type].presence || 'text',
      'lead_message' => message_payload[:body],
      'expected' => message_payload.fetch(:expected, {}).to_h.stringify_keys
    }
  end

  def finalize_step(step)
    checks = checks_for(step)
    step.merge('checks' => checks, 'passed' => checks.all? { |check| check['passed'] })
  end

  def checks_for(step)
    step.fetch('expected', {}).map do |key, expected|
      actual = actual_value_for(step, key)
      { 'name' => key, 'expected' => expected, 'actual' => actual, 'passed' => actual == expected }
    end
  end

  def actual_value_for(step, key)
    case key.to_s
    when 'quality'
      step.dig('qualification', 'quality')
    when 'no_real_send'
      !step['sender_invoked']
    else
      step[key.to_s]
    end
  end

  def metrics_for(steps)
    {
      'reviewed_qualification_accuracy' => ratio_for(steps, 'quality'),
      'serious_issue_count' => serious_issue_count(steps),
      'total_steps' => steps.size
    }
  end

  def ratio_for(steps, expected_key)
    applicable = steps.select { |step| !step['duplicate_ignored'] && step.dig('expected', expected_key).present? }
    return nil if applicable.blank?

    (applicable.count { |step| actual_value_for(step, expected_key) == step.dig('expected', expected_key) }.to_f / applicable.size).round(2)
  end

  def serious_issue_count(steps)
    steps.count do |step|
      step['selected_answer'].present? &&
        step['source_references'].blank? &&
        step['review_request'].blank? &&
        step['message_type'] == 'text'
    end
  end

  def create_run!(simulation)
    AiLeadEmployee::EvaluationRun.create!(
      account: account,
      user: user,
      scenario_key: scenario[:key],
      scenario_name: scenario[:name],
      status: simulation[:status],
      automated_passed: simulation[:steps].all? { |step| step['passed'] } && simulation.dig(:metrics, 'serious_issue_count').to_i.zero?,
      passed: false,
      review_status: :pending_review,
      messages: scenario[:messages],
      steps: simulation[:steps],
      metrics: simulation[:metrics],
      expected_results: scenario,
      configuration_snapshot: configuration_snapshot,
      knowledge_snapshot: knowledge_snapshot,
      provider_snapshot: simulation[:provider_snapshot],
      prompt_version: PROMPT_VERSION,
      simulation_identifier: simulation_identifier,
      completed_at: Time.current
    )
  end

  def failed_run(error)
    AiLeadEmployee::EvaluationRun.create!(
      account: account,
      user: user,
      scenario_key: scenario[:key],
      scenario_name: scenario[:name],
      status: :failed,
      automated_passed: false,
      passed: false,
      review_status: :pending_review,
      messages: scenario[:messages],
      steps: [{ 'error' => error.message }],
      metrics: { 'serious_issue_count' => 1 },
      expected_results: scenario,
      configuration_snapshot: configuration_snapshot,
      knowledge_snapshot: knowledge_snapshot,
      provider_snapshot: provider_snapshot,
      prompt_version: PROMPT_VERSION,
      simulation_identifier: simulation_identifier,
      completed_at: Time.current
    )
  end

  def evidence_payload(conversation)
    QualificationEvidence.where(account: account, conversation: conversation).map do |evidence|
      {
        'signal' => evidence.signal,
        'value' => evidence.value['value'],
        'source' => evidence.source,
        'message_id' => evidence.message_id,
        'source_reference' => evidence.value['source_reference'],
        'observed_at' => evidence.observed_at&.iso8601
      }
    end
  end

  def qualification_payload(qualification)
    return if qualification.blank?

    {
      'quality' => qualification.quality,
      'score' => qualification.score,
      'reasons' => qualification.reasons,
      'missing_signals' => qualification.missing_signals,
      'evidence_snapshot' => qualification.evidence_snapshot,
      'follow_up_state' => qualification.follow_up_state,
      'configuration_version' => qualification.configuration_version
    }
  end

  def review_request_payload(request)
    return if request.blank?

    request.slice(:id, :reason, :status, :question, :conversation_id, :lead_message_id)
  end

  def handoff_decision(intent, qualification)
    return 'blocked' if intent.blocked?
    return 'handoff_requested' if LeadHandoff.exists?(account: account, conversation: intent.conversation)
    return 'handoff_required' if qualification&.highly_qualified?

    'continue_ai'
  end

  def booking_decision(intent, qualification)
    return 'not_evaluated' if intent.blocked?
    return 'not_eligible' unless qualification&.highly_qualified?

    AiLeadEmployee::BookingAvailabilityService.new(account: account, days: 7).perform.slots.present? ? 'booking_available' : 'booking_unavailable'
  end

  def follow_up_decision(intent, qualification)
    return 'not_evaluated' if intent.blocked?
    return 'not_eligible' if qualification.blank? || qualification.unqualified? || qualification.highly_qualified?
    return 'not_eligible' if qualification.follow_up_state.in?(%w[human_review call_booked closed])
    return 'no_unanswered_question' if intent.decision.dig('qualification', 'next_question').blank?

    qualification.qualified? ? 'schedule_qualified_nurture' : 'schedule_incomplete_qualification'
  end

  def configuration_snapshot
    {
      'qualification_config_version' => configuration_version,
      'questions' => account.qualification_questions.enabled_in_order.map do |question|
        question.slice(:id, :signal, :prompt, :position, :updated_at).as_json
      end,
      'booking' => AiLeadEmployee::BookingConfiguration.for(account)
    }
  end

  def knowledge_snapshot
    @knowledge_snapshot ||= begin
      items = account.knowledge_items.usable_by_ai_employee.order(:id).map do |item|
        item.slice(:id, :title, :question, :source_kind, :status, :approved_at,
                   :updated_at).as_json.merge('source_reference' => item.source_reference)
      end
      { 'version' => Digest::SHA256.hexdigest(items.to_json), 'items' => items }
    end
  end

  def provider_snapshot
    connection = account.ai_provider_connection
    { 'provider' => connection&.provider, 'model' => connection&.model, 'status' => connection&.status }
  end

  def provider_snapshot_for(steps)
    provider_snapshot.merge('model' => steps.filter_map { |step| step['provider_model'] }.first || provider_snapshot['model'])
  end

  def configuration_version
    account.settings.to_h.fetch('qualification_config_version', 1).to_i
  end

  def text_message?(message_payload)
    message_payload[:type].blank? || message_payload[:type] == 'text'
  end

  def incoming_content(message_payload)
    text_message?(message_payload) ? message_payload[:body].to_s : I18n.t('conversations.messages.whatsapp.unsupported_message')
  end

  def opt_out?(conversation, incoming_message)
    AiLeadEmployee::OptOutService.new(conversation: conversation, message: incoming_message).perform.present?
  end

  def simulation_source_id
    @simulation_source_id ||= "255#{SecureRandom.random_number(1_000_000_000).to_s.rjust(9, '0')}"
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
