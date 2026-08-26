# frozen_string_literal: true

class Meta::Whatsapp::TextMessageClient
  class SendFailed < StandardError; end

  def initialize(whatsapp_channel:)
    @whatsapp_channel = whatsapp_channel
  end

  def send_text!(recipient:, content:)
    response = send_to_meta(recipient: recipient, content: content)
    response.fetch('messages').first.fetch('id')
  end

  private

  attr_reader :whatsapp_channel

  def send_to_meta(recipient:, content:)
    uri = URI("https://graph.facebook.com/#{graph_api_version}/#{whatsapp_channel.provider_config.fetch('phone_number_id')}/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request(uri, recipient: recipient, content: content))
    raise SendFailed, response.body unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def request(uri, recipient:, content:)
    Net::HTTP::Post.new(uri).tap do |request|
      request['Authorization'] = "Bearer #{whatsapp_channel.provider_config.fetch('api_key')}"
      request['Content-Type'] = 'application/json'
      request.body = {
        messaging_product: 'whatsapp',
        to: recipient,
        type: 'text',
        text: { body: content }
      }.to_json
    end
  end

  def graph_api_version
    ENV.fetch('META_GRAPH_API_VERSION', 'v23.0')
  end
end
