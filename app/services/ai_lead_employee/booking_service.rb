# frozen_string_literal: true

class AiLeadEmployee::BookingService # rubocop:disable Metrics/ClassLength
  PREPARATION_ALERT_TYPE = 'booking_preparation'

  Result = Struct.new(:booking, :created, keyword_init: true)

  class SlotUnavailable < StandardError; end
  class NotHighlyQualified < StandardError; end

  def initialize(conversation:, qualification:, starts_at:, idempotency_key:)
    @conversation = conversation
    @qualification = qualification
    @starts_at = starts_at
    @idempotency_key = idempotency_key
    @account = conversation.account
    @configuration = AiLeadEmployee::BookingConfiguration.for(account)
  end

  def perform
    raise NotHighlyQualified unless qualification&.highly_qualified?

    booking, created = find_or_create_booking!
    deliver_missing_side_effects!(booking)
    Result.new(booking: booking.reload, created: created)
  rescue ActiveRecord::RecordNotUnique
    if (booking = find_idempotent_booking)
      deliver_missing_side_effects!(booking)
      return Result.new(booking: booking.reload, created: false)
    end

    raise SlotUnavailable
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?('index_bookings_on_active_slot_overlap')

    raise SlotUnavailable
  end

  private

  attr_reader :account, :conversation, :qualification, :starts_at, :idempotency_key, :configuration

  def find_or_create_booking!
    booking = nil
    created = false

    Booking.transaction(requires_new: true) do
      booking = Booking.find_by(account: account, idempotency_key: idempotency_key) if idempotency_key.present?
      unless booking
        raise SlotUnavailable unless slot_available?

        booking = Booking.create!(booking_attributes)
        created = true
        mark_call_booked!
      end
    end

    [booking, created]
  end

  def find_idempotent_booking
    return if idempotency_key.blank?

    Booking.find_by(account: account, idempotency_key: idempotency_key)
  end

  def booking_attributes
    {
      account: account,
      contact: conversation.contact,
      conversation: conversation,
      lead_qualification: qualification,
      assignee: conversation.assignee,
      calendar_id: configuration.fetch('calendar_id'),
      provider: configuration.fetch('provider'),
      idempotency_key: idempotency_key,
      starts_at: starts_at,
      ends_at: starts_at + duration,
      timezone: configuration.fetch('timezone'),
      qualification_evidence_ids: qualification_evidence_ids,
      qualification_snapshot: qualification_snapshot,
      confirmed_at: Time.current
    }
  end

  def slot_available?
    AiLeadEmployee::BookingAvailabilityService.new(
      account: account,
      from: starts_at - configuration.fetch('minimum_notice_minutes').to_i.minutes,
      days: 1
    ).perform.slots.include?(starts_at)
  end

  def mark_call_booked!
    qualification.update!(follow_up_state: :call_booked)
    conversation.reload.with_lock do
      conversation.control_state = :human_active
      conversation.control_version += 1
      conversation.assignee_agent_bot = nil
      conversation.status = :open
      conversation.save!
    end
  end

  def deliver_missing_side_effects!(booking)
    create_calendar_event!(booking) if booking.provider_event_id.blank?
    send_confirmation!(booking) if booking.confirmation_message_id.blank?
    send_preparation_alerts!(booking) if booking.preparation_alert_deliveries.blank?
  end

  def create_calendar_event!(booking)
    payload = calendar_client.create_event!(booking: booking)
    booking.update!(
      provider_event_id: payload.fetch('provider_event_id'),
      calendar_event_payload: payload,
      calendar_invitation_sent_at: booking.contact.email.present? ? Time.current : nil
    )
  end

  def send_confirmation!(booking)
    provider_message_id = text_message_client.send_text!(
      recipient: conversation.contact_inbox.source_id,
      content: confirmation_text(booking)
    )
    Message.create!(
      account: account,
      inbox: conversation.inbox,
      conversation: conversation,
      message_type: :outgoing,
      content_type: :text,
      content: confirmation_text(booking),
      status: :sent,
      source_id: provider_message_id
    )
    booking.update!(confirmation_message_id: provider_message_id)
  end

  def send_preparation_alerts!(booking)
    recipients = alert_recipients
    deliveries = recipients.map { |recipient| deliver_preparation_alert(recipient, booking) }
    booking.update!(preparation_alert_recipients: recipients, preparation_alert_deliveries: deliveries)
  end

  def deliver_preparation_alert(recipient, booking)
    {
      recipient: recipient,
      status: 'sent',
      provider_message_id: text_message_client.send_text!(recipient: recipient, content: preparation_alert_text(booking))
    }
  rescue StandardError => e
    {
      recipient: recipient,
      status: 'failed',
      error: e.message
    }
  end

  def alert_recipients
    routes = Array(account.settings&.dig('ai_lead_employee', 'alert_routes', PREPARATION_ALERT_TYPE))
    routes = [{ 'type' => 'assignee' }] if routes.blank?
    routes.filter_map { |route| recipient_for(route) }.flatten.compact.uniq
  end

  def recipient_for(route)
    case route.to_h['type']
    when 'assignee'
      conversation.assignee&.custom_attributes&.dig('whatsapp_alert_phone')
    when 'admin'
      account.administrators.map { |admin| admin.custom_attributes&.dig('whatsapp_alert_phone') }
    else
      route.to_h['recipient']
    end
  end

  def confirmation_text(booking)
    "Your call is booked for #{booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z')}."
  end

  def preparation_alert_text(booking)
    evidence = qualification.evidence_snapshot
    [
      'Call booked with Hot Lead',
      "Lead: #{conversation.contact.name} #{conversation.contact.phone_number} #{conversation.contact.email}".squish,
      "When: #{booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z')}",
      "Summary: #{qualification.reasons.join('; ')}",
      "Strongest evidence: #{strongest_evidence}",
      "Likely objection: #{evidence.dig('budget', 'value').to_s.include?('$') ? 'Budget fit' : 'Timing or budget fit'}",
      'Suggested opening question: What would make this call most useful for you today?'
    ].join("\n")
  end

  def strongest_evidence
    qualification.evidence_snapshot.slice('problem', 'urgency', 'budget', 'decision_authority').map do |signal, evidence|
      "#{signal.humanize}: #{evidence['value']}"
    end.join('; ')
  end

  def qualification_snapshot
    {
      'quality' => qualification.quality,
      'score' => qualification.score,
      'reasons' => qualification.reasons,
      'evidence' => qualification.evidence_snapshot,
      'configuration_version' => qualification.configuration_version
    }
  end

  def qualification_evidence_ids
    qualification.evidence_snapshot.values.filter_map { |evidence| evidence['evidence_id'] }
  end

  def duration
    configuration.fetch('duration_minutes').to_i.minutes
  end

  def text_message_client
    @text_message_client ||= Meta::Whatsapp::TextMessageClient.new(whatsapp_channel: conversation.inbox.channel)
  end

  def calendar_client
    @calendar_client ||= AiLeadEmployee::BookingCalendarClient.new(account: account)
  end
end
