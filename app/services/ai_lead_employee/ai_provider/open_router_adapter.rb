# frozen_string_literal: true

class AiLeadEmployee::AiProvider::OpenRouterAdapter
  API_BASE_URL = 'https://openrouter.ai/api/v1'
  APP_TITLE = 'AI Lead Employee'
  TIMEOUT_SECONDS = 15
  TRANSPORT_ERRORS = [
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    EOFError,
    OpenSSL::SSL::SSLError,
    SocketError
  ].freeze
  TIMEOUT_ERRORS = [
    Net::OpenTimeout,
    Net::ReadTimeout,
    Timeout::Error
  ].freeze

  def initialize(connection:)
    @connection = connection
  end

  def complete(messages:, max_tokens: 512, temperature: 0.2, response_format: nil)
    response = HTTParty.post(
      chat_completions_url,
      headers: headers,
      body: request_body(messages: messages, max_tokens: max_tokens, temperature: temperature, response_format: response_format).to_json,
      timeout: TIMEOUT_SECONDS
    )

    handle_http_failure!(response) unless response.success?
    parse_response(response.body)
  rescue *TIMEOUT_ERRORS
    raise AiLeadEmployee::AiProvider::TimeoutFailure, 'AI provider request timed out'
  rescue *TRANSPORT_ERRORS
    raise AiLeadEmployee::AiProvider::TransportFailure, 'AI provider transport failed'
  rescue JSON::ParserError
    raise AiLeadEmployee::AiProvider::InvalidResponseFailure, 'AI provider returned invalid JSON'
  end

  private

  attr_reader :connection

  def chat_completions_url
    "#{API_BASE_URL}/chat/completions"
  end

  def headers
    {
      'Authorization' => "Bearer #{connection.api_key}",
      'Content-Type' => 'application/json',
      'X-OpenRouter-Title' => APP_TITLE
    }
  end

  def request_body(messages:, max_tokens:, temperature:, response_format:)
    {
      model: connection.model,
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature,
      stream: false,
      provider: {
        data_collection: 'deny',
        zdr: true
      }
    }.tap do |body|
      body[:response_format] = response_format if response_format.present?
    end
  end

  def handle_http_failure!(response)
    case response.code.to_i
    when 401, 403
      raise AiLeadEmployee::AiProvider::AuthenticationFailure, "AI provider rejected credentials with HTTP #{response.code}"
    when 402
      raise AiLeadEmployee::AiProvider::InsufficientCreditsFailure, 'AI provider has insufficient credits'
    when 429
      raise AiLeadEmployee::AiProvider::RateLimitFailure, 'AI provider rate limit reached'
    else
      raise AiLeadEmployee::AiProvider::SafetyRefusalFailure, 'AI provider refused the request' if safety_response_body?(response.body)

      raise AiLeadEmployee::AiProvider::TransportFailure, "AI provider request failed with HTTP #{response.code}"
    end
  end

  def parse_response(body)
    payload = JSON.parse(body)
    raise AiLeadEmployee::AiProvider::InvalidResponseFailure, 'AI provider response was not an object' unless payload.is_a?(Hash)

    choice = response_choice(payload)
    message = choice.fetch('message', nil)
    finish_reason = choice.fetch('finish_reason', nil)
    raise AiLeadEmployee::AiProvider::InvalidResponseFailure, 'AI provider response did not include an assistant message' unless message.is_a?(Hash)
    raise AiLeadEmployee::AiProvider::SafetyRefusalFailure, 'AI provider refused the request' if safety_refusal?(message, finish_reason)

    content = message.fetch('content', nil)
    raise AiLeadEmployee::AiProvider::InvalidResponseFailure, 'AI provider response did not include assistant content' if content.blank?

    build_response(payload, content, finish_reason)
  end

  def response_choice(payload)
    choice = Array(payload['choices']).first
    return choice if choice.is_a?(Hash)

    raise AiLeadEmployee::AiProvider::InvalidResponseFailure, 'AI provider response did not include a choice'
  end

  def build_response(payload, content, finish_reason)
    AiLeadEmployee::AiProvider::Response.new(
      id: payload['id'],
      model: payload['model'] || connection.model,
      content: content,
      finish_reason: finish_reason,
      input_tokens: integer_usage(payload, 'prompt_tokens'),
      output_tokens: integer_usage(payload, 'completion_tokens'),
      total_tokens: integer_usage(payload, 'total_tokens'),
      cost_usd: decimal_usage(payload, 'cost')
    )
  end

  def integer_usage(payload, key)
    value = payload.dig('usage', key)
    value.to_i if value.is_a?(Integer) && value >= 0
  end

  def decimal_usage(payload, key)
    value = payload.dig('usage', key)
    BigDecimal(value.to_s) if value.is_a?(Numeric) && value >= 0
  end

  def safety_refusal?(message, finish_reason)
    finish_reason.to_s.in?(%w[content_filter safety refusal]) ||
      message.to_h['refusal'].present?
  end

  def safety_response_body?(body)
    body.to_s.match?(/safety|refusal|content_filter/i)
  end
end
