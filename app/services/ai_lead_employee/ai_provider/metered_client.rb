# frozen_string_literal: true

class AiLeadEmployee::AiProvider::MeteredClient
  Reservation = Data.define(:usage_id, :configuration_version, :period_on)
  MAX_INPUT_BYTES = 32.kilobytes

  def initialize(connection:, adapter:)
    @connection = connection
    @adapter = adapter
  end

  def complete(messages:, max_tokens: connection.reply_token_limit, temperature: 0.2, response_format: nil,
               purpose: 'answer')
    validate_input!(messages)
    validate_output!(max_tokens)
    reservation = reserve_usage!(purpose: purpose, max_tokens: max_tokens)
    complete_reserved!(reservation, messages, max_tokens, temperature, response_format)
  rescue AiLeadEmployee::AiProvider::InputLimitFailure, AiLeadEmployee::AiProvider::OutputLimitFailure
    raise
  rescue AiLeadEmployee::AiProvider::UsageLimitFailure => e
    AiLeadEmployee::AiProvider::RuntimeControl.stop_pending_automation!(
      account: connection.account,
      reason: e.failure_class
    )
    raise
  rescue AiLeadEmployee::AiProvider::ProviderFailure => e
    clean_up_provider_failure(reservation, e) unless e.is_a?(AiLeadEmployee::AiProvider::AccountingUncertainFailure)
    raise
  end

  private

  attr_reader :connection, :adapter

  def validate_input!(messages)
    return if serialized_input_bytes(messages) <= MAX_INPUT_BYTES

    raise AiLeadEmployee::AiProvider::InputLimitFailure, 'AI provider input exceeds the 32 KiB limit'
  end

  def serialized_input_bytes(messages)
    Array(messages).map do |message|
      values = message.to_h.with_indifferent_access
      { role: values[:role], content: values[:content] }
    end.to_json.bytesize
  end

  def validate_output!(max_tokens)
    return if max_tokens.is_a?(Integer) && max_tokens.positive? && max_tokens <= connection.reply_token_limit

    raise AiLeadEmployee::AiProvider::OutputLimitFailure, 'Requested output exceeds the configured reply token ceiling'
  end

  def complete_reserved!(reservation, messages, max_tokens, temperature, response_format)
    response = request_provider_response(messages, max_tokens, temperature, response_format)
    finalize_response!(reservation, response)
  end

  def request_provider_response(messages, max_tokens, temperature, response_format)
    adapter.complete(
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      response_format: response_format
    )
  rescue AiLeadEmployee::AiProvider::ProviderFailure
    raise
  rescue StandardError
    raise AiLeadEmployee::AiProvider::AccountingUncertainFailure,
          'AI provider outcome is uncertain after an unexpected response-processing failure'
  end

  def finalize_response!(reservation, response)
    response.configuration_version = reservation.configuration_version
    response.usage_period_on = reservation.period_on
    complete_usage!(reservation.usage_id, response)
    response
  rescue StandardError
    raise AiLeadEmployee::AiProvider::AccountingUncertainFailure,
          'AI provider responded but durable usage completion is uncertain'
  end

  def reserve_usage!(purpose:, max_tokens:)
    with_usage_ledger do |connection_class, usage_class|
      current = connection_class.find(connection.id)
      current.with_lock do
        validate_reservation!(current)
        usage = create_usage!(usage_class, current, purpose, max_tokens)
        Reservation.new(
          usage_id: usage.id,
          configuration_version: current.configuration_version,
          period_on: usage.period_on
        )
      end
    end
  end

  def validate_reservation!(current)
    raise AiLeadEmployee::AiProvider::DisabledFailure, 'AI provider connection is disabled' unless current.configured?
    if current.configuration_version != connection.configuration_version
      raise AiLeadEmployee::AiProvider::ConfigurationChangedFailure, 'AI provider configuration changed'
    end

    used = current.usages.for_utc_day(Time.current.utc.to_date).count
    raise AiLeadEmployee::AiProvider::UsageLimitFailure, 'Daily AI request allowance is exhausted' if current.daily_request_limit <= used
  end

  def create_usage!(usage_class, current, purpose, max_tokens)
    usage_class.create!(
      account_id: current.account_id,
      ai_provider_connection_id: current.id,
      configuration_version: current.configuration_version,
      purpose: purpose,
      period_on: Time.current.utc.to_date,
      requested_output_tokens: max_tokens,
      started_at: Time.current
    )
  end

  def complete_usage!(usage_id, response)
    with_usage_ledger do |_connection_class, usage_class|
      usage_class.find(usage_id).update!(
        status: 'completed',
        provider_request_id: response.id,
        model: response.model,
        input_tokens: response.input_tokens,
        output_tokens: response.output_tokens,
        total_tokens: response.total_tokens,
        cost_usd: response.cost_usd,
        cost_available: response.cost_usd.present?,
        completed_at: Time.current
      )
    end
  end

  def fail_usage!(usage_id, failure_class)
    return unless usage_id

    with_usage_ledger do |_connection_class, usage_class|
      usage_class.find(usage_id).update!(
        status: 'failed',
        failure_class: failure_class,
        completed_at: Time.current
      )
    end
  end

  def record_provider_failure!(reservation, failure_class)
    return unless reservation

    with_usage_ledger do |connection_class, _usage_class|
      current = connection_class.find(connection.id)
      current.with_lock do
        next unless current.configured? && current.configuration_version == reservation.configuration_version

        current.update!(provider_failure_attributes(current, reservation, failure_class))
      end
    end
  end

  def provider_failure_attributes(current, reservation, failure_class)
    {
      last_health_checked_at: Time.current,
      last_health_status: 'failed',
      last_health_failure_class: failure_class,
      last_health_configuration_version: reservation.configuration_version,
      last_health_response: {
        status: 'failed', failure_class: failure_class, configuration_version: reservation.configuration_version,
        reply_token_limit: current.reply_token_limit, model: current.model
      }
    }
  end

  def with_usage_ledger
    return yield(AiLeadEmployee::AiProviderConnection, AiLeadEmployee::AiProviderUsage) unless ActiveRecord::Base.connection.transaction_open?

    AiLeadEmployee::AiProviderLedgerRecord.connection_pool.with_connection do
      yield(AiLeadEmployee::AiProviderLedgerConnection, AiLeadEmployee::AiProviderLedgerUsage)
    end
  rescue ActiveRecord::ConnectionTimeoutError, ActiveRecord::ConnectionNotEstablished => e
    raise AiLeadEmployee::AiProvider::AdmissionUnavailableFailure, "AI provider usage admission unavailable: #{e.message}"
  end

  def attempt_cleanup(operation:, reservation:, failure:)
    yield
  rescue StandardError => e
    report_cleanup_failure(operation: operation, reservation: reservation, failure: failure, error: e)
    nil
  end

  def report_cleanup_failure(operation:, reservation:, failure:, error:)
    Rails.logger.error(
      '[AI PROVIDER] provider_failure_cleanup_failed ' \
      "operation=#{operation} account_id=#{connection.account_id} connection_id=#{connection.id} " \
      "usage_id=#{reservation&.usage_id || 'none'} provider_failure_class=#{failure.failure_class} " \
      "cleanup_error_class=#{error.class.name}"
    )
  rescue StandardError
    nil
  end

  def clean_up_provider_failure(reservation, failure)
    cleanup_context = { reservation: reservation, failure: failure }
    attempt_cleanup(operation: 'fail_usage', **cleanup_context) { fail_usage!(reservation&.usage_id, failure.failure_class) }
    attempt_cleanup(operation: 'record_provider_failure', **cleanup_context) { record_provider_failure!(reservation, failure.failure_class) }
  end
end
