# frozen_string_literal: true

class AiLeadEmployee::BookingMutationService # rubocop:disable Metrics/ClassLength
  class SlotUnavailable < StandardError; end

  class ProviderRejected < StandardError
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

  class AuthorityChanged < StandardError; end

  def initialize(account:, user:, booking:, action:, attributes:, idempotency_key:, calendar_client: nil) # rubocop:disable Metrics/ParameterLists
    @account = account
    @user = user
    @booking = booking
    @action = action.to_s
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key.presence || "#{action}-#{booking.id}-#{Time.current.to_i}"
    @calendar_client = calendar_client || AiLeadEmployee::BookingCalendarClient.new(account: account)
  end

  def perform # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    ensure_matching_operation!
    return booking.reload if applied?

    validate_provider_available!(desired_booking) if new_reschedule_operation?
    desired = stage_operation!
    payload = action == 'cancel' ? calendar_client.cancel_event!(booking: desired) : calendar_client.update_event!(booking: desired)
    finalize_after_provider!(desired, payload)
  rescue AiLeadEmployee::GoogleCalendarClient::ProviderFailure => e
    return booking.reload unless record_provider_failure!(e)

    raise ProviderUnknown, booking if e.uncertain?

    raise ProviderRejected, e.error_code
  rescue Faraday::Error, Timeout::Error
    failure = AiLeadEmployee::GoogleCalendarClient::ProviderFailure.new(
      error_code: 'provider_timeout', state: 'connection_error'
    )
    return booking.reload unless record_provider_failure!(failure)

    raise ProviderUnknown, booking
  end

  def reconcile_unknown! # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    ensure_matching_operation!
    mutation = mutation_record
    raise ProviderRejected, 'booking_provider_state_not_unknown' unless mutation&.fetch('state', nil) == 'unknown'

    @availability_authority_digest = mutation['availability_authority_digest']
    desired = desired_booking(mutation)
    event = calendar_client.fetch_event!(
      calendar_id: mutation['calendar_id'].presence || booking.calendar_id,
      event_id: mutation['provider_event_id'].presence || booking.provider_event_id
    )
    case provider_operation_state(event, desired, mutation)
    when :applied
      finalize_after_provider!(desired, reconciliation_payload(event, desired))
    when :not_applied
      resolve_provider_operation_not_applied!(desired, event)
    else
      return booking.reload unless record_reconciliation_unknown!('provider_event_diverged')

      raise ProviderUnknown, booking
    end
  rescue AiLeadEmployee::GoogleCalendarClient::ProviderFailure => e
    return finalize_after_provider!(desired, reconciliation_payload({}, desired)) if action == 'cancel' && e.error_code == 'event_not_found'
    return booking.reload unless record_reconciliation_unknown!(e.error_code)

    raise ProviderUnknown, booking
  rescue Faraday::Error, Timeout::Error
    return booking.reload unless record_reconciliation_unknown!('provider_timeout')

    raise ProviderUnknown, booking
  end

  private

  attr_reader :account, :user, :booking, :action, :attributes, :idempotency_key, :calendar_client

  def applied?
    mutation = booking.reload.calendar_event_payload.to_h.dig('mutations', idempotency_key)
    mutation&.fetch('state', nil) == 'confirmed'
  end

  def ensure_matching_operation! # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
    mutation = booking.reload.calendar_event_payload.to_h.dig('mutations', idempotency_key)
    return unless mutation

    matches = mutation['action'] == action
    matches &&= Time.zone.parse(mutation.fetch('starts_at')) == Time.zone.parse(attributes.fetch(:starts_at)) if action == 'reschedule'
    matches &&= mutation['reason'].to_s == attributes[:reason].to_s if action == 'cancel'
    raise ProviderRejected, 'idempotency_key_payload_mismatch' unless matches
  rescue ArgumentError, KeyError
    raise ProviderRejected, 'idempotency_key_payload_mismatch'
  end

  def stage_operation! # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    desired = nil
    Booking.transaction do
      booking.conversation.reload.lock!('FOR NO KEY UPDATE')
      booking.lock!
      mutation = mutation_record
      if mutation&.fetch('state', nil).in?(%w[pending unknown])
        desired = desired_booking(mutation)
        @availability_authority_digest = mutation['availability_authority_digest']
        validate_availability_authority! if action == 'reschedule'
        lock_mutation_slot!(desired) if action == 'reschedule'
        return desired
      end

      validate_action!
      reject_unresolved_operation!
      desired = desired_booking
      validate_availability_authority! if action == 'reschedule'
      lock_mutation_slot!(desired) if action == 'reschedule'
      validate_local_available!(desired) if action == 'reschedule'
      remember_operation!(desired, 'pending')
    end
    desired
  end

  def validate_action!
    raise ProviderRejected, 'booking_not_confirmed' unless booking.confirmed? || booking.provider_unknown?
    raise ProviderRejected, 'invalid_booking_action' unless action.in?(%w[reschedule cancel])
  end

  def reject_unresolved_operation!
    operation = booking.provider_operation.to_h
    return unless operation['state'].in?(%w[pending unknown])
    return if operation['idempotency_key'] == idempotency_key

    raise ProviderRejected, 'booking_provider_operation_unresolved'
  end

  def desired_booking(mutation = nil)
    duplicate = booking.dup
    duplicate.id = booking.id
    duplicate.provider_event_id = booking.provider_event_id
    if action == 'reschedule'
      starts_at = Time.zone.parse(mutation&.fetch('starts_at', nil) || attributes.fetch(:starts_at))
      duration = booking.ends_at - booking.starts_at
      duplicate.starts_at = starts_at
      duplicate.ends_at = starts_at + duration
    end
    duplicate
  end

  def new_reschedule_operation?
    action == 'reschedule' && !mutation_record&.fetch('state', nil).in?(%w[pending unknown])
  end

  def validate_provider_available!(desired)
    days = [(desired.starts_at.to_date - Time.current.to_date).to_i + 1, 1].max
    availability = AiLeadEmployee::BookingAvailabilityService.new(
      account: account, from: Time.current, days: days, calendar_client: calendar_client, exclude_booking: booking
    )
    result = availability.perform
    @availability_authority_digest = availability.authority_digest
    raise ProviderRejected, result.error_code if result.provider_state != 'connected'
    raise SlotUnavailable unless result.slots.include?(desired.starts_at)
  end

  def validate_local_available!(desired)
    configuration = AiLeadEmployee::BookingConfiguration.for(account)
    buffer_before = configuration.fetch('buffer_before_minutes').to_i.minutes
    buffer_after = configuration.fetch('buffer_after_minutes').to_i.minutes
    conflict = Booking.active.where(account: account, calendar_id: booking.calendar_id).where.not(id: booking.id)
                      .exists?(['starts_at < ? AND ends_at > ?', desired.ends_at + buffer_after,
                                desired.starts_at - buffer_before])
    raise SlotUnavailable if conflict
  end

  def finalize_after_provider!(desired, provider_payload)
    finalize_operation!(desired, provider_payload)
  rescue SlotUnavailable, AuthorityChanged => e
    code = e.is_a?(AuthorityChanged) ? 'booking_configuration_changed_after_provider_update' : 'local_slot_conflict_after_provider_update'
    return booking.reload unless record_provider_outcome_unknown!(desired, code)

    raise ProviderUnknown, booking
  end

  def finalize_operation!(desired, provider_payload) # rubocop:disable Metrics/AbcSize
    Booking.transaction do
      booking.conversation.reload.lock!('FOR NO KEY UPDATE')
      booking.lock!
      return booking if mutation_record&.fetch('state', nil) == 'confirmed'

      validate_availability_authority!(after_provider: true) if action == 'reschedule'
      lock_mutation_slot!(desired) if action == 'reschedule'
      validate_local_available!(desired) if action == 'reschedule'
      apply_provider_result!(desired, provider_payload)
      message = record_whatsapp_notice!
      booking.update!(confirmation_message_id: message.id.to_s)
      remember_operation!(desired, 'confirmed', provider_payload.merge('message_id' => message.id))
      audit_mutation!
    end
    booking.reload
  end

  def record_provider_outcome_unknown!(desired, error_code)
    Booking.transaction do
      booking.conversation.reload.lock!('FOR NO KEY UPDATE')
      booking.with_lock do
        return false if mutation_record&.fetch('state', nil) == 'confirmed'

        remember_operation!(desired, 'unknown', 'error_code' => error_code)
        booking.update!(provider_state: 'unknown', provider_error_code: error_code, provider_checked_at: Time.current)
        true
      end
    end
  end

  def apply_provider_result!(desired, provider_payload) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    if action == 'cancel'
      booking.assign_attributes(status: :canceled, provider_state: 'canceled')
      booking.lead_qualification&.update!(follow_up_state: :human_review)
    else
      booking.assign_attributes(starts_at: desired.starts_at, ends_at: desired.ends_at, status: :confirmed,
                                provider_state: 'confirmed')
      booking.lead_qualification&.update!(follow_up_state: :call_booked)
    end
    booking.provider_error_code = nil
    booking.provider_checked_at = Time.current
    booking.calendar_event_payload = event_payload.merge(provider_payload).merge(
      action == 'cancel' ? {
        'calendar_state' => 'canceled', 'canceled_at' => Time.current.iso8601,
        'cancel_reason' => attributes[:reason].presence || 'Canceled by Human Operator'
      } : {
        'calendar_state' => 'confirmed', 'rescheduled_at' => Time.current.iso8601,
        'starts_at' => desired.starts_at.iso8601, 'ends_at' => desired.ends_at.iso8601
      }
    )
    booking.save!
  end

  def record_provider_failure!(failure)
    Booking.transaction do
      booking.conversation.reload.lock!('FOR NO KEY UPDATE')
      booking.lock!
      return false if mutation_record&.fetch('state', nil) == 'confirmed'

      desired = desired_booking(mutation_record)
      remember_operation!(desired, failure.uncertain? ? 'unknown' : 'failed', 'error_code' => failure.error_code)
      booking.update!(provider_state: failure.uncertain? ? 'unknown' : 'failed',
                      provider_error_code: failure.error_code, provider_checked_at: Time.current)
      true
    end
  end

  def validate_availability_authority!(after_provider: false)
    current = AiLeadEmployee::BookingConfiguration.authority_digest(account.reload)
    return if current == @availability_authority_digest

    raise AuthorityChanged if after_provider

    raise ProviderRejected, 'booking_configuration_changed_retry'
  end

  def lock_mutation_slot!(_desired)
    key = [account.id, booking.calendar_id].join(':')
    quoted_key = Booking.connection.quote(key)
    Booking.connection.execute("SELECT pg_advisory_xact_lock(hashtextextended(#{quoted_key}, 0))")
  end

  def remember_operation!(desired, state, additions = {}) # rubocop:disable Metrics/AbcSize
    payload = booking.calendar_event_payload.to_h
    mutations = payload.fetch('mutations', {}).dup
    existing = mutations[idempotency_key].to_h
    mutations[idempotency_key] = {
      'action' => action, 'state' => state, 'user_id' => user.id, 'idempotency_key' => idempotency_key,
      'starts_at' => desired.starts_at.iso8601, 'ends_at' => desired.ends_at.iso8601,
      'reason' => attributes[:reason], 'updated_at' => Time.current.iso8601,
      'availability_authority_digest' => @availability_authority_digest,
      'calendar_id' => booking.calendar_id,
      'provider_event_id' => booking.provider_event_id,
      'original_starts_at' => existing['original_starts_at'] || booking.starts_at.iso8601,
      'original_ends_at' => existing['original_ends_at'] || booking.ends_at.iso8601,
      'original_provider_status' => existing['original_provider_status'] ||
                                    event_payload['calendar_state'].presence || booking.provider_state
    }.merge(additions)
    booking.update!(calendar_event_payload: payload.merge('mutations' => mutations),
                    provider_operation: mutations[idempotency_key])
  end

  def mutation_record
    booking.calendar_event_payload.to_h.dig('mutations', idempotency_key)
  end

  def provider_operation_state(event, desired, mutation)
    return :applied if action == 'cancel' && event['status'].to_s == 'cancelled'
    return :applied if action == 'reschedule' && provider_event_matches?(event, desired.starts_at, desired.ends_at, 'confirmed')

    original_start = Time.zone.parse(mutation.fetch('original_starts_at'))
    original_end = Time.zone.parse(mutation.fetch('original_ends_at'))
    original_status = mutation.fetch('original_provider_status', 'confirmed')
    return :not_applied if provider_event_matches?(event, original_start, original_end, original_status)

    :divergent
  rescue ArgumentError, KeyError, TypeError
    :divergent
  end

  def provider_event_matches?(event, starts_at, ends_at, status)
    event['status'].to_s == status &&
      Time.zone.parse(event.dig('start', 'dateTime').to_s) == starts_at &&
      Time.zone.parse(event.dig('end', 'dateTime').to_s) == ends_at
  rescue ArgumentError, TypeError
    false
  end

  def reconciliation_payload(event, desired)
    {
      'provider_event_id' => event.fetch('id', booking.provider_event_id),
      'calendar_state' => action == 'cancel' ? 'canceled' : 'confirmed',
      'starts_at' => desired.starts_at.iso8601,
      'ends_at' => desired.ends_at.iso8601,
      'meeting_link' => event['hangoutLink'],
      'html_link' => event['htmlLink'],
      'etag' => event['etag']
    }.compact
  end

  def resolve_provider_operation_not_applied!(desired, event)
    Booking.transaction do
      booking.conversation.reload.lock!('FOR NO KEY UPDATE')
      booking.lock!
      return booking if mutation_record&.fetch('state', nil) == 'confirmed'

      remember_operation!(desired, 'not_applied', 'inspected_provider_status' => event['status'])
      booking.update!(provider_state: 'confirmed', provider_error_code: nil, provider_checked_at: Time.current)
    end
    booking.reload
  end

  def record_reconciliation_unknown!(error_code)
    Booking.transaction do
      booking.conversation.reload.lock!('FOR NO KEY UPDATE')
      booking.lock!
      return false if mutation_record&.fetch('state', nil).in?(%w[confirmed not_applied])

      desired = desired_booking(mutation_record)
      remember_operation!(desired, 'unknown', 'error_code' => error_code, 'reconciled_at' => Time.current.iso8601)
      booking.update!(provider_state: 'unknown', provider_error_code: error_code, provider_checked_at: Time.current)
      true
    end
  end

  def audit_mutation!
    Audited::Audit.create!(
      auditable: booking, associated: account, user: user, action: 'update',
      audited_changes: {
        'ai_lead_employee_action' => "booking_#{action}", 'idempotency_key' => idempotency_key,
        'starts_at' => booking.saved_change_to_starts_at, 'status' => booking.saved_change_to_status
      }.compact,
      version: Audited::Audit.where(auditable: booking).maximum(:version).to_i + 1,
      created_at: Time.current
    )
  end

  def record_whatsapp_notice!
    booking.conversation.messages.create!(
      account: account, inbox: booking.conversation.inbox, sender: user,
      message_type: :outgoing, content_type: :text, content: notice_text,
      additional_attributes: { ai_lead_employee: { booking_id: booking.id, booking_mutation_key: idempotency_key } }
    )
  end

  def notice_text
    return 'Your booked call has been canceled. A Human Operator will follow up with next steps.' if action == 'cancel'

    "Your call has been rescheduled for #{booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z')}."
  end

  def event_payload
    booking.calendar_event_payload.to_h
  end
end
