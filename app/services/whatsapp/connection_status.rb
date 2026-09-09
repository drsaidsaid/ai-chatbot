class Whatsapp::ConnectionStatus
  def initialize(channel)
    @channel = channel
  end

  def payload
    return { status: 'not_connected' } unless @channel

    {
      status: status, inbox_id: @channel.inbox.id, name: @channel.inbox.name,
      phone_number: @channel.phone_number, **@channel.safe_provider_config.symbolize_keys,
      callback_url: "#{ENV.fetch('FRONTEND_URL', '')}/webhooks/whatsapp/#{@channel.phone_number}",
      webhook_registered_at: @channel.webhook_registered_at, webhook_error_code: @channel.webhook_error_code,
      **health_payload, **receiving_payload
    }
  end

  def receipts
    Whatsapp::WebhookReceipt.where('verified_routes @> ?', [{ channel_id: @channel.id, account_id: @channel.account_id }].to_json)
  end

  def events
    Whatsapp::WebhookEvent.where(channel: @channel, account_id: @channel.account_id, inbox_id: @channel.inbox.id)
  end

  private

  def health_payload
    {
      health_checked_at: @channel.phone_number_health_checked_at,
      health_error_code: safe_health_error,
      provider_status: @channel.phone_number_health['status']
    }
  end

  def receiving_payload
    {
      last_accepted_at: receipts.maximum(:created_at), last_processed_at: incoming.processed.maximum(:processed_at),
      pending_count: events.where(state: [:pending, :failed]).count + receipts.where(expanded_at: nil).count,
      awaiting_delivery_count: events.awaiting_message.count,
      failed_count: events.failed.count, receiving_error_code: receiving_error
    }
  end

  def safe_health_error
    return if @channel.phone_number_health_error.blank?

    @channel.phone_number_health_error == 'authorization' ? 'authorization' : 'provider_unavailable'
  end

  def receiving_error
    return 'processing_failed' if events.failed.exists?
    return 'queue_unavailable' if receipts.exists?(expanded_at: nil, error_code: 'queue_unavailable')
  end

  def incoming
    events.where(kind: 'messages')
  end

  def status
    return 'incomplete' unless @channel.connection_configured?
    return 'needs_attention' if needs_attention?
    return 'check_required' unless checked_and_connected?
    return 'awaiting_message' unless incoming.processed.exists?

    'receiving'
  end

  def needs_attention?
    @channel.webhook_error_code.present? || safe_health_error.present? || receiving_error.present? ||
      Whatsapp::HealthService::RISKY_STATUSES.include?(@channel.phone_number_health['status'])
  end

  def checked_and_connected?
    @channel.webhook_registered_at && @channel.phone_number_health_checked_at &&
      @channel.phone_number_health['status'] == 'CONNECTED' && @channel.phone_number_health['code_verification_status'] == 'VERIFIED'
  end
end
