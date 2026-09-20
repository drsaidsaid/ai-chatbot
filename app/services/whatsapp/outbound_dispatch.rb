class Whatsapp::OutboundDispatch
  Rejected = Class.new(StandardError)
  AcceptanceUnknown = Class.new(StandardError)
  AuthorizationCanceled = Class.new(StandardError)
  def initialize(message:, channel:, recipient:, template: nil)
    @message = message
    @delivery = message&.whatsapp_outbound_delivery
    @owner = SecureRandom.uuid
    @channel = channel
    @connection_snapshot = connection_snapshot
    @recipient = recipient
    @template = template
  end

  def perform
    return unless @delivery
    return unless claim

    provider_id = yield(method(:request))
    usable_provider_id?(provider_id) ? accept(provider_id) : unknown!
    provider_id
  rescue AuthorizationCanceled
    nil
  rescue Rejected
    fail!
    nil
  rescue StandardError
    unknown! unless @delivery&.fail_preparation!(owner: @owner)
    nil
  end

  private

  # Arguments are fully prepared before this call, including dispatch-time media
  # capabilities and JSON serialization. Only the HTTP operation crosses the boundary.
  def request(url, **options)
    raise AuthorizationCanceled unless authorize

    HTTParty.post(url, options)
  end

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
    with_authority_locks do |owner|
      @delivery.reload
      next false unless @delivery.claimed? && @delivery.owner_token == @owner && @delivery.lease_expires_at.future?

      next false unless greeting_ready?(owner)

      code = eligibility_failure || owner.admission_failure(@delivery)
      if code
        owner.cancel!(@delivery, reason: code)
        next false
      end
      admitted_at = Time.current
      owner.admit!(@delivery, at: admitted_at)
      @delivery.update!(state: :dispatching, dispatch_started_at: admitted_at, lease_expires_at: 1.minute.from_now)
      @delivery.publish!
      true
    end
  end

  def connection_snapshot
    [@channel.provider, @channel.phone_number, @channel.provider_config.deep_dup]
  end

  def eligibility_failure
    return 'connection_changed' unless @connection_snapshot == connection_snapshot

    Whatsapp::OutboundEligibility.new(delivery: @delivery, channel: @channel, recipient: @recipient, template: @template,
                                      authority_records: @authority_records,
                                      alert_authority: @outbound_alert_authority).failure_code
  end

  def with_authority_locks(&) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    @message.reload
    @outbound_alert_authority = Whatsapp::OutboundAlertAuthority.new(@message)
    origin_id = @outbound_alert_authority.origin_id
    Conversation.transaction do
      # Canonical ingress also locks Channel before Conversation.
      @channel.lock!
      # Lock only owned Conversations, in stable order, including an alert's origin.
      # NO KEY UPDATE still serializes control changes while allowing foreign-key
      # inserts by booking preparation already holding its originating record.
      Conversation.where(account_id: @delivery.account_id, id: [@delivery.conversation_id, origin_id].compact)
                  .order(:id).lock('FOR NO KEY UPDATE').load
      @delivery.conversation.reload
      origin = Conversation.find_by(account_id: @delivery.account_id, id: origin_id) || @delivery.conversation
      AiLeadEmployee::OfferDeliveryContext.new(
        conversation: origin, context: @message.additional_attributes.dig('ai_lead_employee', 'qualification_context')
      ).lock_offers!
      pilot_authorization = pilot_authorization_authority
      # These authorities were formerly acquired by eligibility after Delivery.
      # Prelock them at their rank; eligibility only reuses the owned rows.
      provider_connection = AiLeadEmployee::AiProviderConnection.where(account_id: @delivery.account_id).lock.first
      provider_usage = pilot_provider_usage_authority
      orchestration_intent = pilot_orchestration_intent_authority
      membership = AccountUser.where(account_id: @delivery.account_id, user_id: @message.sender_id).lock.first if @message.sender_type == 'User'
      confirmation_booking = booking_confirmation_authority
      @authority_records = {
        provider_connection: provider_connection, pilot_authorization: pilot_authorization,
        provider_usage: provider_usage, orchestration_intent: orchestration_intent, membership: membership,
        confirmation_booking: confirmation_booking
      }.freeze
      @outbound_alert_authority.lock_record!
      Whatsapp::DeliveryLifecycle.with(deliveries: Whatsapp::OutboundDelivery.where(id: @delivery.id), &)
    end
  end

  def booking_confirmation_authority
    attributes = @message.additional_attributes.fetch('ai_lead_employee', {})
    return unless attributes['delivery_type'] == 'booking_confirmation'

    Booking.where(account_id: @delivery.account_id, id: attributes['booking_id']).lock.first
  end

  def pilot_authorization_authority
    id = @message.additional_attributes.dig('ai_lead_employee', 'pilot_authorization_id')
    return unless id

    AiLeadEmployee::PilotAuthorization.where(account_id: @delivery.account_id, id: id).lock.first
  end

  def pilot_provider_usage_authority
    id = @message.additional_attributes.dig('ai_lead_employee', 'provider_usage_id')
    return unless id

    AiLeadEmployee::AiProviderUsage.where(account_id: @delivery.account_id, id: id).lock.first
  end

  def pilot_orchestration_intent_authority
    return unless @message.additional_attributes.dig('ai_lead_employee', 'pilot_authorization_id')

    id = @message.additional_attributes.dig('ai_lead_employee', 'orchestration_intent_id')
    return unless id

    AiLeadEmployee::OrchestrationIntent.where(account_id: @delivery.account_id, id: id).lock.first
  end

  def greeting_ready?(owner) # rubocop:disable Metrics/CyclomaticComplexity
    return true if @message.sender_type == 'User'

    predecessor = earlier_greeting
    return true unless predecessor
    return true if predecessor.accepted?

    state = predecessor.state.in?(%w[pending claimed dispatching]) ? 'pending' : 'canceled'
    @delivery.update!(state: state, owner_token: nil, lease_expires_at: nil, attempts: @delivery.attempts - 1,
                      failure_code: state == 'canceled' ? 'greeting_not_accepted' : nil)
    owner.cancel_artifact!(owner.artifact_for(@delivery), reason: 'greeting_not_accepted') if state == 'canceled' && owner.artifact_for(@delivery)
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
    @delivery.with_lifecycle(review: true) do |owner, reviews|
      next unless @delivery.owner_token == @owner && @delivery.state.in?(%w[dispatching unknown])

      @message.reload.update!(source_id: provider_id, external_error: nil)
      @delivery.update!(state: :accepted, provider_message_id: provider_id, accepted_at: Time.current, failure_code: nil)
      owner.outcome!(@delivery)
      reviews.select(&:open?).each do |review|
        review.update!(status: :resolved, resolved_at: Time.current, resolution_kind: 'provider_accepted')
      end
      @delivery.publish!
    end
  end

  def unknown!
    return unless @delivery

    @delivery.with_lifecycle(review: true) do |owner, reviews|
      next unless @delivery.owner_token == @owner && @delivery.dispatching?

      @delivery.record_unknown_locked!(owner, reviews)
    end
  end

  def fail!
    @delivery.with_lifecycle do |owner, _reviews|
      next unless @delivery.owner_token == @owner && @delivery.dispatching?

      @delivery.update!(state: :failed, failure_code: 'provider_rejected')
      owner.outcome!(@delivery)
      @message.reload.update!(status: :failed, external_error: Whatsapp::MessageStatusProjector::SAFE_DELIVERY_ERROR)
      @delivery.publish!
    end
  end
end
