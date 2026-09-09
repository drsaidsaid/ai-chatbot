class Whatsapp::EventProcessor
  def initialize(event)
    @event = event
  end

  def perform
    @event.with_lock do
      return if @event.terminal?
      return if @event.next_attempt_at && @event.next_attempt_at > Time.current

      process_locked_event
    end
    enqueue_intents
  rescue StandardError => e
    @event.reload
    return enqueue_intents if @event.terminal?

    code = e.is_a?(Whatsapp::IncomingMessageWhatsappCloudService::MediaUnavailable) ? 'media_unavailable' : 'processing_failed'
    @event.update!(state: :failed, attempts: @event.attempts + 1, error_code: code, next_attempt_at: 1.minute.from_now)
    Rails.logger.warn("[WHATSAPP EVENT] processing_failed event_id=#{@event.id}")
  end

  private

  def process_locked_event
    # One number per Business Account: serialize first-conversation creation
    # across provider events and alternate sender identifiers in the database.
    @event.channel.lock!
    verify_scope!
    @event.increment(:attempts)
    state = @event.kind == 'statuses' ? Whatsapp::DeliveryStatusProjector.new(@event).perform : process_message
    awaiting = state == :awaiting_message
    @event.update!(state: state, processed_at: awaiting ? nil : Time.current,
                   error_code: awaiting ? 'awaiting_message' : nil, next_attempt_at: awaiting ? 1.minute.from_now : nil)
  end

  def verify_scope!
    raise ActiveRecord::RecordInvalid unless @event.channel.account_id == @event.account_id && @event.inbox.account_id == @event.account_id
    raise ActiveRecord::RecordInvalid unless @event.inbox.channel == @event.channel
    raise ActiveRecord::RecordInvalid unless @event.account.active?
  end

  def process_message
    Whatsapp::IncomingMessageWhatsappCloudService.new(
      inbox: @event.inbox, params: @event.payload.with_indifferent_access,
      outgoing_echo: @event.kind == 'message_echoes', durable_event: @event
    ).perform
    @event.inbox.messages.exists?(source_id: @event.provider_message_id) ? :processed : :ignored
  end

  def enqueue_intents
    return unless @event.kind == 'messages'

    messages = @event.inbox.messages.where(source_id: @event.provider_message_id)
    AiLeadEmployee::OrchestrationIntent.pending.where(triggering_message_id: messages.select(:id)).find_each do |intent|
      AiLeadEmployee::OrchestrationIntentJob.perform_later(intent.id)
    end
  rescue StandardError
    Rails.logger.warn("[WHATSAPP EVENT] intent_queue_unavailable event_id=#{@event.id}")
  end
end
