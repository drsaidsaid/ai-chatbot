# frozen_string_literal: true

class AiLeadEmployee::AiProvider::MeteredClient
  Reservation = Data.define(:usage_id, :configuration_version)
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
    fail_usage!(reservation&.usage_id, e.failure_class)
    record_provider_failure!(reservation, e.failure_class)
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
    response = adapter.complete(
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      response_format: response_format
    )
    response.configuration_version = reservation.configuration_version
    complete_usage!(reservation.usage_id, response)
    response
  end

  def reserve_usage!(purpose:, max_tokens:)
    persistently do
      current = AiLeadEmployee::AiProviderConnection.find(connection.id)
      current.with_lock do
        validate_reservation!(current)
        usage = create_usage!(current, purpose, max_tokens)
        Reservation.new(usage_id: usage.id, configuration_version: current.configuration_version)
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

  def create_usage!(current, purpose, max_tokens)
    AiLeadEmployee::AiProviderUsage.create!(
      account: current.account,
      ai_provider_connection: current,
      configuration_version: current.configuration_version,
      purpose: purpose,
      period_on: Time.current.utc.to_date,
      requested_output_tokens: max_tokens,
      started_at: Time.current
    )
  end

  def complete_usage!(usage_id, response)
    persistently do
      AiLeadEmployee::AiProviderUsage.find(usage_id).update!(
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

    persistently do
      AiLeadEmployee::AiProviderUsage.find(usage_id).update!(
        status: 'failed',
        failure_class: failure_class,
        completed_at: Time.current
      )
    end
  end

  def record_provider_failure!(reservation, failure_class)
    return unless reservation

    persistently do
      current = AiLeadEmployee::AiProviderConnection.find(connection.id)
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

  def persistently(&)
    return yield unless ActiveRecord::Base.connection.transaction_open?

    worker = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection(&)
    end
    worker.report_on_exception = false
    worker.value
  end
end
