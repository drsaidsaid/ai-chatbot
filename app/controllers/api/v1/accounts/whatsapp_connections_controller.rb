class Api::V1::Accounts::WhatsappConnectionsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?

  def show
    render json: status_payload
  end

  def update
    current_account.with_lock do
      @connection = connection || current_account.whatsapp_channels.build(provider: 'whatsapp_cloud')
      save_configuration(connection_params.to_h)
    end
    check_connection
    render json: status_payload
  rescue ActiveRecord::RecordNotUnique
    render json: { error: 'connection_exists' }, status: :conflict
  rescue ActiveRecord::RecordInvalid
    render json: { error: 'invalid_configuration' }, status: :unprocessable_entity
  end

  def health_check
    return head :not_found unless connection

    check_connection
    render json: status_payload
  end

  def retry_receiving
    return head :not_found unless connection

    status = Whatsapp::ConnectionStatus.new(connection)
    # Retry scheduling must not validate or mutate the durable payload.
    status.events.where(state: [:failed, :awaiting_message]).update_all(next_attempt_at: nil) # rubocop:disable Rails/SkipsModelValidations
    status.receipts.where(expanded_at: nil).or(status.receipts.where(id: status.events.recoverable.select(:receipt_id))).find_each(&:enqueue)
    render json: status_payload
  end

  private

  def connection
    @connection ||= current_account.whatsapp_channels.find_by(provider: 'whatsapp_cloud')
  end

  def save_configuration(values)
    @connection.phone_number = values['phone_number'] if values.key?('phone_number')
    @connection.provider_config = @connection.provider_config.merge(values.except('name', 'phone_number').compact_blank)
    if @connection.persisted?
      @connection.save!
      @connection.inbox.update!(name: values['name']) if values['name'].present?
    else
      current_account.inboxes.create!(name: values['name'].presence || 'WhatsApp', channel: @connection)
    end
  end

  def connection_params
    params.permit(:name, :phone_number, :phone_number_id, :business_account_id, :api_key, :app_secret)
  end

  def status_payload
    Whatsapp::ConnectionStatus.new(connection&.reload).payload
  end

  def check_connection
    return unless connection.connection_configured?

    connection.setup_webhooks unless connection.webhook_registered_at
    Whatsapp::HealthService.new(connection).sync_health_status!
  rescue StandardError
    # The provider services persist classified failures. No provider response or
    # exception text is reflected to the browser.
    Rails.logger.warn("[WHATSAPP CONNECTION] check_failed channel_id=#{connection.id}")
  end
end
