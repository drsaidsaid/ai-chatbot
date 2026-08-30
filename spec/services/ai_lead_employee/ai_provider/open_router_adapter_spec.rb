# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiLeadEmployee::AiProvider::OpenRouterAdapter do
  let(:connection) { instance_double(AiLeadEmployee::AiProviderConnection, api_key: 'sk-or-adapter-secret', model: 'openai/gpt-5.2') }
  let(:messages) { [{ role: 'user', content: 'Can you answer from approved sources?' }] }

  it 'sends an OpenAI-compatible chat completion request with OpenRouter privacy routing isolated in the adapter', :aggregate_failures do
    request = stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
              .with do |request|
      body = JSON.parse(request.body)
      expect(request.headers).to include(
        'Authorization' => 'Bearer sk-or-adapter-secret',
        'Content-Type' => 'application/json',
        'X-Openrouter-Title' => 'AI Lead Employee'
      )
      expect(body).to include(
        'model' => 'openai/gpt-5.2',
        'messages' => [{ 'role' => 'user', 'content' => 'Can you answer from approved sources?' }],
        'stream' => false,
        'provider' => { 'data_collection' => 'deny', 'zdr' => true }
      )
    end.to_return(
      status: 200,
      body: {
        id: 'chatcmpl-provider',
        model: 'openai/gpt-5.2',
        choices: [{ message: { role: 'assistant', content: '{"status":"ready"}' }, finish_reason: 'stop' }]
      }.to_json,
      headers: { 'content-type' => 'application/json' }
    )

    result = described_class.new(connection: connection).complete(messages: messages, max_tokens: 32)

    expect(request).to have_been_requested
    expect(result).to have_attributes(id: 'chatcmpl-provider', content: '{"status":"ready"}', model: 'openai/gpt-5.2')
  end

  {
    401 => AiLeadEmployee::AiProvider::AuthenticationFailure,
    403 => AiLeadEmployee::AiProvider::AuthenticationFailure,
    429 => AiLeadEmployee::AiProvider::RateLimitFailure
  }.each do |status, failure|
    it "classifies HTTP #{status} as #{failure.name.demodulize}" do
      stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(status: status, body: { error: { message: 'failed' } }.to_json)

      expect { described_class.new(connection: connection).complete(messages: messages) }.to raise_error(failure) do |error|
        expect(error.message).not_to include('sk-or-adapter-secret')
      end
    end
  end

  it 'classifies timeouts' do
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_timeout

    expect { described_class.new(connection: connection).complete(messages: messages) }.to raise_error(AiLeadEmployee::AiProvider::TimeoutFailure)
  end

  it 'classifies transport failures' do
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_raise(SocketError.new('getaddrinfo failed'))

    expect { described_class.new(connection: connection).complete(messages: messages) }.to raise_error(AiLeadEmployee::AiProvider::TransportFailure)
  end

  it 'classifies malformed provider responses' do
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(status: 200, body: { choices: [] }.to_json)

    expect do
      described_class.new(connection: connection).complete(messages: messages)
    end.to raise_error(AiLeadEmployee::AiProvider::InvalidResponseFailure)
  end

  it 'classifies valid JSON with the wrong shape as an invalid response' do
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions').to_return(status: 200, body: [].to_json)

    expect do
      described_class.new(connection: connection).complete(messages: messages)
    end.to raise_error(AiLeadEmployee::AiProvider::InvalidResponseFailure)
  end

  it 'classifies safety refusals' do
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .to_return(
        status: 200,
        body: {
          id: 'chatcmpl-refusal',
          choices: [{ message: { role: 'assistant', refusal: 'Cannot comply.' }, finish_reason: 'stop' }]
        }.to_json
      )

    expect do
      described_class.new(connection: connection).complete(messages: messages)
    end.to raise_error(AiLeadEmployee::AiProvider::SafetyRefusalFailure)
  end
end
