class Whatsapp::OutboundDispatch
  Rejected = Class.new(StandardError)
  AcceptanceUnknown = Class.new(StandardError)
  def initialize(message:, channel:, recipient:, template: nil)
    @message = message
    @delivery = message&.whatsapp_outbound_delivery
    @owner = SecureRandom.uuid
    @channel = channel
    @recipient = recipient
    @template = template
  end

  def perform
    return unless @delivery
    return unless claim
    return unless authorize

    provider_id = yield
    usable_provider_id?(provider_id) ? accept(provider_id) : unknown!
    provider_id
  rescue Rejected
    fail!
    nil
  rescue StandardError
    unknown!
    nil
  end

  private

  def usable_provider_id?(provider_id)
    provider_id.is_a?(String) && provider_id.present? && provider_id.bytesize <= 512
  end

  def claim
    @delivery.with_lock do
      next false unless @delivery.pending?

      @delivery.update!(state: :claimed, owner_token: @owner, attempts: @delivery.attempts + 1, lease_expires_at: 1.minute.from_now)
      true
    end
  end

  def authorize
    with_authority_locks do
      @delivery.lock!
      next false unless @delivery.claimed? && @delivery.owner_token == @owner && @delivery.lease_expires_at.future?

      next false unless greeting_ready?

      code = Whatsapp::OutboundEligibility.new(delivery: @delivery, channel: @channel, recipient: @recipient, template: @template).failure_code
      if code
        @delivery.update!(state: :canceled, failure_code: code)
        @delivery.publish!
        next false
      end
      @delivery.update!(state: :dispatching, dispatch_started_at: Time.current, lease_expires_at: 1.minute.from_now)
      @delivery.publish!
      true
    end
  end

  def with_authority_locks
    @message.reload
    origin_id = Whatsapp::OutboundAlertAuthority.new(@message).origin_id
    Conversation.transaction do
      # Lock only owned Conversations, in stable order, including an alert's origin.
      Conversation.where(account_id: @delivery.account_id, id: [@delivery.conversation_id, origin_id].compact).order(:id).lock.load
      @delivery.conversation.reload
      yield
    end
  end

  def greeting_ready?
    return true if @message.sender_type == 'User'

    predecessor = earlier_greeting
    return true unless predecessor
    return true if predecessor.accepted?

    state = predecessor.state.in?(%w[pending claimed dispatching]) ? 'pending' : 'canceled'
    @delivery.update!(state: state, owner_token: nil, lease_expires_at: nil, attempts: @delivery.attempts - 1,
                      failure_code: state == 'canceled' ? 'greeting_not_accepted' : nil)
    @delivery.publish!
    false
  end

  def earlier_greeting
    Whatsapp::OutboundDelivery.joins(:message)
                              .where(account_id: @delivery.account_id, conversation_id: @delivery.conversation_id)
                              .where(observed_control_version: @delivery.observed_control_version, messages: { id: ...@message.id })
                              .where("messages.additional_attributes #>> '{ai_lead_employee,delivery_type}' = 'channel_greeting'")
                              .order(:id).first
  end

  def accept(provider_id)
    @delivery.with_lock do
      return unless @delivery.owner_token == @owner

      @message.update!(source_id: provider_id, external_error: nil)
      @delivery.update!(state: :accepted, provider_message_id: provider_id, accepted_at: Time.current, failure_code: nil)
      HumanReviewRequest.open.where(account_id: @delivery.account_id, lead_message_id: @message.id, reason: :delivery_unknown).find_each do |review|
        review.update!(status: :resolved, resolved_at: Time.current, resolution_kind: 'provider_accepted')
      end
      @delivery.publish!
    end
  end

  def unknown!
    return unless @delivery

    @delivery.with_lock do
      return unless @delivery.owner_token == @owner && @delivery.dispatching?

      @delivery.record_unknown!
    end
  end

  def fail!
    @delivery.with_lock do
      return unless @delivery.owner_token == @owner && @delivery.dispatching?

      @delivery.update!(state: :failed, failure_code: 'provider_rejected')
      @message.update!(status: :failed, external_error: Whatsapp::MessageStatusProjector::SAFE_DELIVERY_ERROR)
      @delivery.publish!
    end
  end
end
