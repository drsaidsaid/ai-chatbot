class Whatsapp::MessageStatusProjector
  STATUSES = %w[sent delivered read failed].freeze
  SAFE_DELIVERY_ERROR = 'WhatsApp could not deliver this message. Check the connection before retrying.'.freeze

  def initialize(message:, status:, provider_created_at: nil)
    @message = message
    @status = status.deep_stringify_keys
    @provider_created_at = provider_created_at || parse_provider_time
  end

  def perform
    return unless STATUSES.include?(@status['status'])

    @message.with_lock do
      next unless may_advance?

      @message.update!(status: @status['status'], content_attributes: projected_attributes)
    end
  end

  private

  def parse_provider_time
    Time.at(Integer(@status['timestamp'])).utc
  rescue ArgumentError, TypeError, RangeError
    nil
  end

  def projected_attributes
    attributes = @message.content_attributes.merge('whatsapp_delivery_timestamp' => @provider_created_at&.to_i,
                                                   'whatsapp_provider_status' => @status['status'])
    if @status['status'] == 'failed'
      attributes['whatsapp_delivery_error_code'] = @status.dig('errors', 0, 'code').to_s[/\A\d+\z/]
      attributes['external_error'] = SAFE_DELIVERY_ERROR
    else
      attributes.delete('external_error')
      attributes.delete('whatsapp_delivery_error_code')
    end
    attributes
  end

  def may_advance?
    incoming = @status['status']
    existing = @message.status
    return false if existing == 'read'
    return incoming == 'read' if existing == 'delivered'

    !stale_update?(incoming, existing)
  end

  def stale_update?(incoming, existing)
    existing_time = @message.content_attributes['whatsapp_delivery_timestamp'].to_i
    incoming_time = @provider_created_at.to_i
    ((incoming == existing || incoming == 'failed') && incoming_time < existing_time) ||
      (existing == 'failed' && incoming == 'sent' && incoming_time <= existing_time)
  end
end
