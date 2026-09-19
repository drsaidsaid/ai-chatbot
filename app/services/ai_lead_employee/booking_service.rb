# frozen_string_literal: true

class AiLeadEmployee::BookingService # rubocop:disable Metrics/ClassLength
  PREPARATION_ALERT_TYPE = 'booking_preparation'

  Result = Struct.new(:booking, :created, keyword_init: true)

  class SlotUnavailable < StandardError; end

  class Ineligible < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.humanize)
    end
  end

  class ProviderUnknown < StandardError
    attr_reader :booking

    def initialize(booking)
      @booking = booking
      super('Google Calendar did not return a conclusive result; reconciliation is required')
    end
  end

  def initialize(conversation:, qualification:, starts_at:, idempotency_key:, agreement_message:, agreed_starts_at:, # rubocop:disable Metrics/ParameterLists
                 attendee_email: nil, calendar_client: nil, prerequisite_checker: nil)
    @conversation = conversation
    @qualification = qualification
    @starts_at = starts_at
    @idempotency_key = idempotency_key
    @agreement_message = agreement_message
    @agreed_starts_at = agreed_starts_at
    @attendee_email = attendee_email.presence
    @calendar_client = calendar_client
    @prerequisite_checker = prerequisite_checker
    @account = conversation.account
    @configuration = AiLeadEmployee::BookingConfiguration.for(account)
  end

  def perform # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    if (existing = find_idempotent_booking)
      @eligibility = Struct.new(:offer).new(existing.offer)
      ensure_matching_request!(existing)
      confirm_provider_event!(existing) unless existing.confirmed?
      deliver_missing_side_effects!(existing) if existing.reload.confirmed?
      return Result.new(booking: existing.reload, created: false)
    end

    authorize_booking!
    raise SlotUnavailable unless provider_slot_available?

    booking, created = find_or_create_booking!
    ensure_matching_request!(booking)
    confirm_provider_event!(booking) unless booking.confirmed?
    deliver_missing_side_effects!(booking) if booking.confirmed?
    Result.new(booking: booking.reload, created: created)
  rescue ActiveRecord::RecordNotUnique
    if (booking = find_idempotent_booking)
      @eligibility = Struct.new(:offer).new(booking.offer)
      ensure_matching_request!(booking)
      confirm_provider_event!(booking) unless booking.confirmed?
      deliver_missing_side_effects!(booking) if booking.reload.confirmed?
      return Result.new(booking: booking.reload, created: false)
    end

    raise SlotUnavailable
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?('index_bookings_on_active_slot_overlap')

    raise SlotUnavailable
  end

  def reconcile_unknown!(booking)
    raise Ineligible, 'booking_provider_state_not_unknown' unless booking.provider_unknown? && booking.account_id == account.id

    @eligibility = Struct.new(:offer).new(booking.offer)
    confirm_provider_event!(booking)
    deliver_missing_side_effects!(booking.reload) if booking.reload.confirmed?
    Result.new(booking: booking.reload, created: false)
  end

  private

  attr_reader :account, :conversation, :qualification, :starts_at, :idempotency_key, :configuration,
              :agreement_message, :agreed_starts_at, :attendee_email, :prerequisite_checker

  def authorize_booking! # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    raise Ineligible, 'calendar_not_connected' unless configuration['connected']
    raise Ineligible, 'specific_agreed_time_required' unless agreed_starts_at == starts_at
    unless agreement_message&.incoming? && agreement_message.conversation_id == conversation.id &&
           agreement_message.sender_id == conversation.contact_id
      raise Ineligible, 'lead_agreement_message_required'
    end

    @eligibility = AiLeadEmployee::BookingEligibility.new(
      conversation: conversation,
      qualification: qualification,
      prerequisite_checker: prerequisite_checker
    ).perform
    raise Ineligible, @eligibility.failure_code unless @eligibility.eligible?
    raise Ineligible, 'lead_agreement_message_required' unless @eligibility.agreement_evidence.message_id == agreement_message.id

    evidence_time = Time.zone.parse(@eligibility.agreement_evidence.value['agreed_starts_at'].to_s)
    raise Ineligible, 'specific_agreed_time_required' unless evidence_time == starts_at
  rescue ArgumentError, TypeError
    raise Ineligible, 'specific_agreed_time_required'
  end

  def find_or_create_booking!
    booking = nil
    created = false

    Booking.transaction(requires_new: true) do
      lock_and_revalidate_authority!
      lock_booking_slot!
      booking = Booking.find_by(account: account, idempotency_key: idempotency_key) if idempotency_key.present?
      unless booking
        raise SlotUnavailable unless local_slot_available?

        booking = Booking.create!(booking_attributes)
        created = true
      end
    end

    [booking, created]
  end

  def lock_and_revalidate_authority!
    conversation.reload.lock!
    conversation.offer&.lock!
    qualification&.reload&.lock!
    agreement_message&.reload&.lock!
    @configuration = AiLeadEmployee::BookingConfiguration.for(account.reload)
    current_authority_digest = AiLeadEmployee::BookingConfiguration.authority_digest(account, configuration: @configuration)
    raise Ineligible, 'booking_configuration_changed_retry' unless @availability_authority_digest == current_authority_digest

    authorize_booking!
    @eligibility.agreement_evidence.lock!
  end

  def lock_booking_slot!
    key = [account.id, configuration.fetch('calendar_id')].join(':')
    quoted_key = Booking.connection.quote(key)
    Booking.connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{quoted_key}, 0))")
  end

  def find_idempotent_booking
    return if idempotency_key.blank?

    Booking.find_by(account: account, idempotency_key: idempotency_key)
  end

  def booking_attributes # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    {
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification,
      offer: @eligibility.offer,
      agreement_evidence: @eligibility.agreement_evidence,
      agreement_message: agreement_message,
      assignee: conversation.assignee,
      calendar_id: configuration.fetch('calendar_id'),
      provider: configuration.fetch('provider'),
      idempotency_key: idempotency_key,
      starts_at: starts_at,
      ends_at: starts_at + duration,
      timezone: configuration.fetch('timezone'),
      status: :pending,
      provider_state: 'pending',
      agreed_at: agreement_message.provider_created_at || agreement_message.created_at,
      attendee_email: attendee_email,
      calendar_event_payload: {
        'call_type' => @eligibility.offer.next_step['kind'],
        'booked_channel' => 'WhatsApp'
      },
      prerequisite_snapshot: @eligibility.prerequisite_snapshot,
      qualification_evidence_ids: qualification_evidence_ids,
      qualification_snapshot: qualification_snapshot
    }
  end

  def provider_slot_available?
    availability = AiLeadEmployee::BookingAvailabilityService.new(
      account: account,
      from: Time.current,
      days: [(starts_at.to_date - Time.current.to_date).to_i + 1, 1].max,
      calendar_client: calendar_client
    )
    result = availability.perform
    @availability_authority_digest = availability.authority_digest
    raise Ineligible, result.error_code unless result.provider_state == 'connected'

    result.slots.include?(starts_at)
  end

  def local_slot_available?
    buffer_before = configuration.fetch('buffer_before_minutes').to_i.minutes
    buffer_after = configuration.fetch('buffer_after_minutes').to_i.minutes
    ends_at = starts_at + duration
    !Booking.active.where(account: account, calendar_id: configuration.fetch('calendar_id'))
            .exists?(['starts_at < ? AND ends_at > ?', ends_at + buffer_after, starts_at - buffer_before])
  end

  def ensure_matching_request!(booking) # rubocop:disable Metrics/CyclomaticComplexity
    matches = booking.conversation_id == conversation.id && booking.offer_id == @eligibility.offer&.id &&
              booking.starts_at == starts_at && booking.attendee_email == attendee_email &&
              booking.agreement_message_id == agreement_message&.id
    raise Ineligible, 'idempotency_key_payload_mismatch' unless matches
  end

  def confirm_provider_event!(booking)
    booking.with_lock do
      return if booking.confirmed?

      booking.update!(provider_state: 'creating', provider_error_code: nil,
                      provider_operation: provider_operation(booking, 'create'))
    end

    payload = calendar_client.create_event!(booking: booking.reload)
    finalize_provider_confirmation!(booking, payload)
  rescue AiLeadEmployee::GoogleCalendarClient::ProviderFailure => e
    return booking.reload unless record_provider_failure!(booking, e)

    raise ProviderUnknown, booking if e.uncertain?

    raise Ineligible, e.error_code
  rescue Faraday::Error, Timeout::Error
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    return booking.reload unless record_provider_failure!(booking, failure)

    raise ProviderUnknown, booking
  end

  def finalize_provider_confirmation!(booking, payload)
    conversation.reload.with_lock('FOR NO KEY UPDATE') do
      booking.lock!
      return booking if booking.confirmed? && booking.provider_state == 'confirmed'

      booking.update!(
        status: :confirmed,
        provider_state: 'confirmed',
        provider_event_id: payload.fetch('provider_event_id'),
        provider_error_code: nil,
        provider_checked_at: Time.current,
        provider_operation: provider_operation(booking, 'create').merge('state' => 'confirmed', 'completed_at' => Time.current.iso8601),
        calendar_event_payload: booking.calendar_event_payload.to_h.merge(payload),
        calendar_invitation_sent_at: attendee_email.present? ? Time.current : nil,
        confirmed_at: Time.current
      )
      mark_call_booked!
    end
  end

  def record_provider_failure!(booking, failure)
    booking.with_lock do
      return false if booking.confirmed? && booking.provider_state == 'confirmed'

      booking.update!(
        status: failure.uncertain? ? :provider_unknown : :pending,
        provider_state: failure.uncertain? ? 'unknown' : 'failed',
        provider_error_code: failure.error_code,
        provider_checked_at: Time.current,
        provider_operation: provider_operation(booking, 'create').merge(
          'state' => failure.uncertain? ? 'unknown' : 'failed',
          'error_code' => failure.error_code,
          'completed_at' => Time.current.iso8601
        )
      )
      true
    end
  end

  def provider_operation(booking, action)
    booking.provider_operation.to_h.merge(
      'action' => action,
      'idempotency_key' => idempotency_key,
      'provider_event_id' => AiLeadEmployee::GoogleCalendarClient.event_id_for(booking),
      'started_at' => booking.provider_operation['started_at'] || Time.current.iso8601
    )
  end

  def mark_call_booked!
    qualification&.update!(follow_up_state: :call_booked)
    conversation.control_state = :human_active
    conversation.control_version += 1
    conversation.assignee_agent_bot = nil
    conversation.status = :open
    conversation.save!
  end

  def deliver_missing_side_effects!(booking)
    message_ids_to_deliver = []

    booking.with_lock do
      booking.reload
      message_ids_to_deliver << deliver_confirmation!(booking)
      message_ids_to_deliver.concat(deliver_preparation_alerts!(booking))
    end

    message_ids_to_deliver.compact.each { |message_id| SendReplyJob.perform_later(message_id) }
  end

  def deliver_confirmation!(booking)
    message = confirmation_message(booking)
    return message.id if message&.failed?
    return if message.present?

    message = conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: confirmation_text(booking),
      private: false,
      additional_attributes: confirmation_message_attributes(booking)
    )
    booking.update!(confirmation_message_id: message.id.to_s)
    message.id
  end

  def confirmation_message_attributes(booking)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox',
        booking_id: booking.id,
        delivery_type: 'booking_confirmation'
      }
    }
  end

  def confirmation_message(booking)
    message_id = Integer(booking.confirmation_message_id, exception: false)
    return if message_id.blank?

    account.messages.find_by(id: message_id)
  end

  def retry_message!(message)
    message.id
  end

  def deliver_preparation_alerts!(booking)
    recipients = alert_recipients
    previous_deliveries = booking.preparation_alert_deliveries.index_by { |delivery| delivery['recipient'] }
    message_ids_to_deliver = []
    deliveries = recipients.map do |recipient|
      preparation_alert_delivery_for(recipient, booking, previous_deliveries[recipient], message_ids_to_deliver)
    end
    booking.update!(preparation_alert_recipients: recipients, preparation_alert_deliveries: deliveries)
    message_ids_to_deliver
  end

  def preparation_alert_delivery_for(recipient, booking, previous_delivery, message_ids_to_deliver)
    message = preparation_alert_message_from(previous_delivery)
    created = false
    unless message
      message = create_preparation_alert_message!(recipient, booking)
      created = true
    end
    message_ids_to_deliver << retry_message!(message) if created || message.failed?

    {
      recipient: recipient,
      status: alert_delivery_status(message),
      message_id: message.id,
      conversation_id: message.conversation_id,
      provider_message_id: message.source_id,
      error: message.external_error
    }.compact
  end

  def preparation_alert_message_from(delivery)
    return if delivery.blank?

    message_id = Integer(delivery['message_id'], exception: false)
    return if message_id.blank?

    account.messages.find_by(id: message_id)
  end

  def create_preparation_alert_message!(recipient, booking)
    alert_conversation = AiLeadEmployee::WhatsappAlertConversation.new(
      account: account,
      whatsapp_channel: conversation.inbox.channel,
      recipient: recipient,
      alert_type: PREPARATION_ALERT_TYPE
    ).perform
    alert_conversation.messages.create!(
      account: account,
      inbox: conversation.inbox,
      message_type: :outgoing,
      content_type: :text,
      content: preparation_alert_text(booking),
      private: false,
      additional_attributes: preparation_alert_attributes(recipient, booking)
    )
  end

  def preparation_alert_attributes(recipient, booking)
    {
      ai_lead_employee: {
        delivery_boundary: 'outbox',
        booking_id: booking.id,
        alert_type: PREPARATION_ALERT_TYPE,
        origin_conversation_id: conversation.id,
        origin_control_version: conversation.control_version,
        alert_recipient: recipient
      },
      template_params: preparation_alert_template_params(booking)
    }.compact
  end

  def preparation_alert_template_params(booking)
    return if qualification.blank?

    AiLeadEmployee::HandoffAlertTemplateParams.new(
      account: account,
      conversation: conversation,
      qualification: qualification,
      alert_type: PREPARATION_ALERT_TYPE,
      booking: booking
    ).to_h
  end

  def alert_delivery_status(message)
    return 'sent' if message.source_id.present?
    return 'failed' if message.failed?

    'queued'
  end

  def alert_recipients
    AiLeadEmployee::HandoffAlertRecipients
      .new(account: account, alert_type: PREPARATION_ALERT_TYPE)
      .for(conversation.assignee, fallback_routes: [{ 'type' => 'assignee' }])
  end

  def confirmation_text(booking)
    "Your call is booked for #{booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z')}."
  end

  def preparation_alert_text(booking) # rubocop:disable Metrics/AbcSize
    evidence = qualification&.evidence_snapshot.to_h
    [
      'Call booked with Hot Lead',
      "Open: #{conversation_url}",
      "Lead: #{conversation.contact.name} #{conversation.contact.phone_number} #{conversation.contact.email}".squish,
      "When: #{booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z')}",
      "Summary: #{qualification&.reasons.to_a.join('; ').presence || @eligibility.offer&.name || 'Booked call'}",
      "Strongest evidence: #{strongest_evidence}",
      "Likely objection: #{evidence.dig('budget', 'value').to_s.include?('$') ? 'Budget fit' : 'Timing or budget fit'}",
      'Suggested opening question: What would make this call most useful for you today?'
    ].join("\n")
  end

  def strongest_evidence
    qualification&.evidence_snapshot.to_h.slice('problem', 'urgency', 'budget', 'decision_authority').map do |signal, evidence|
      "#{signal.humanize}: #{evidence['value']}"
    end.join('; ')
  end

  def conversation_url
    base_url = ENV.fetch('FRONTEND_URL', '').presence
    path = "/app/accounts/#{account.id}/conversations/#{conversation.display_id}?queue=bookings"
    base_url ? "#{base_url.delete_suffix('/')}#{path}" : path
  end

  def qualification_snapshot
    return { 'offer' => @eligibility.offer.name, 'offer_id' => @eligibility.offer.id } if qualification.blank?

    {
      'offer' => @eligibility.offer.name,
      'offer_id' => @eligibility.offer.id,
      'quality' => qualification.quality,
      'score' => qualification.score,
      'reasons' => qualification.reasons,
      'evidence' => qualification.evidence_snapshot,
      'configuration_version' => qualification.configuration_version
    }
  end

  def qualification_evidence_ids
    qualification&.evidence_snapshot.to_h.values.filter_map { |evidence| evidence['evidence_id'] }.push(@eligibility.agreement_evidence.id).uniq
  end

  def duration
    configuration.fetch('duration_minutes').to_i.minutes
  end

  def calendar_client
    @calendar_client ||= AiLeadEmployee::BookingCalendarClient.new(account: account)
  end
end
