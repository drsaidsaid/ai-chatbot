class Whatsapp::ReceiptAcceptor
  class InvalidPayload < StandardError; end
  class InvalidSignature < StandardError; end
  class InactiveChannel < StandardError; end

  def initialize(raw_body:, signature:)
    @raw_body = raw_body
    @signature = signature.to_s
  end

  def perform
    routes = verified_routes
    Whatsapp::WebhookReceipt.create_or_find_by!(body_digest: Digest::SHA256.hexdigest(@raw_body)) do |receipt|
      receipt.raw_body = @raw_body
      receipt.verified_routes = routes
    end
  end

  private

  def verified_routes
    payload = JSON.parse(@raw_body)
    raise InvalidPayload unless payload.is_a?(Hash) && payload['object'] == 'whatsapp_business_account'
    raise InvalidPayload unless payload['entry'].is_a?(Array) && payload['entry'].present?

    payload['entry'].each_with_index.flat_map do |entry, entry_index|
      routes_for_entry(entry, entry_index)
    end
  rescue JSON::ParserError, TypeError
    raise InvalidPayload
  end

  def routes_for_entry(entry, entry_index)
    raise InvalidPayload unless entry.is_a?(Hash) && entry['changes'].is_a?(Array) && entry['changes'].present?

    entry['changes'].each_with_index.map do |change, change_index|
      channel = channel_for(entry, change)
      verify!(channel)
      validate_event_arrays!(change.fetch('value'))
      { entry: entry_index, change: change_index, channel_id: channel.id, account_id: channel.account_id, inbox_id: channel.inbox.id }
    end
  end

  def channel_for(entry, change)
    raise InvalidPayload unless change.is_a?(Hash) && change['value'].is_a?(Hash)

    metadata = change['value']['metadata']
    raise InvalidPayload unless metadata.is_a?(Hash)

    channel = Whatsapp::WebhookChannelFinderService.new(
      display_phone_number: metadata['display_phone_number'], phone_number_id: metadata['phone_number_id']
    ).perform
    validate_channel!(channel, entry)
    channel
  end

  def validate_channel!(channel, entry)
    raise InvalidSignature unless channel&.provider == 'whatsapp_cloud' && channel.inbox
    raise InvalidSignature if entry['id'].present? && entry['id'].to_s != channel.provider_config['business_account_id'].to_s
  end

  def validate_event_arrays!(value)
    %w[messages message_echoes statuses].each do |kind|
      next unless value.key?(kind)

      items = value[kind]
      raise InvalidPayload unless items.is_a?(Array) && items.all? { |item| identified_event?(item) }
    end
    validate_contacts!(value) if value.key?('contacts')
  end

  def validate_contacts!(value)
    raise InvalidPayload unless value['contacts'].is_a?(Array) && value['contacts'].all?(Hash)
  end

  def identified_event?(item)
    item.is_a?(Hash) && item['id'].is_a?(String) && item['id'].present?
  end

  def verify!(channel)
    valid = channel.signing_secrets.any? do |secret|
      expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret, @raw_body)}"
      ActiveSupport::SecurityUtils.secure_compare(expected, @signature)
    end
    raise InvalidSignature unless valid

    inactive_numbers = GlobalConfig.get_value('INACTIVE_WHATSAPP_NUMBERS').to_s.split(',').map(&:strip)
    raise InactiveChannel unless channel.account.active?
    raise InactiveChannel if inactive_numbers.include?(channel.phone_number)
  end
end
