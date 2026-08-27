# frozen_string_literal: true

class AiLeadEmployee::BookingsWorkspaceService # rubocop:disable Metrics/ClassLength
  DEFAULT_DAYS = 7

  def initialize(account:, user:, params: {})
    @account = account
    @user = user
    @params = params.to_h.with_indifferent_access
    @configuration = AiLeadEmployee::BookingConfiguration.for(account)
  end

  def perform
    bookings = filtered_bookings.to_a
    {
      bookings: bookings.map { |booking| payload_for(booking) },
      selected_booking: selected_booking_payload(bookings),
      meta: meta_payload(bookings),
      filter_options: filter_options,
      availability: availability_payload,
      calendar: calendar_payload(bookings)
    }
  end

  def payload_for(booking) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    {
      id: booking.id,
      contact_id: booking.contact_id,
      conversation_id: booking.conversation_id,
      lead_qualification_id: booking.lead_qualification_id,
      assignee_id: booking.assignee_id,
      status: booking.status,
      starts_at: booking.starts_at.iso8601,
      ends_at: booking.ends_at.iso8601,
      timezone: booking.timezone,
      call_type: call_type_for(booking),
      offer: offer_for(booking),
      booked_channel: booked_channel_for(booking),
      created_at: booking.created_at.iso8601,
      meeting_link: meeting_link_for(booking),
      provider: booking.provider,
      provider_event_id: booking.provider_event_id,
      calendar_id: booking.calendar_id,
      calendar_state: calendar_state_for(booking),
      whatsapp_state: whatsapp_state_for(booking),
      preparation_state: preparation_state_for(booking),
      contact: contact_payload(booking.contact),
      assignee: user_payload(booking.assignee),
      conversation: conversation_payload(booking.conversation),
      detail: detail_payload(booking)
    }
  end

  private

  attr_reader :account, :user, :params, :configuration

  def filtered_bookings # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    scope = visible_bookings.includes(:contact, :conversation, :assignee)
    scope = scope.where(starts_at: range_start...range_end)
    scope = scope.where(status: params[:status]) if Booking.statuses.key?(params[:status].to_s)
    scope = scope.where(assignee_id: params[:assignee_id]) if params[:assignee_id].present?
    scope = scope.where(timezone: params[:timezone]) if params[:timezone].present?
    scope = scope.select { |booking| offer_for(booking) == params[:offer] } if params[:offer].present?
    scope.respond_to?(:order) ? scope.order(:starts_at, :id) : scope.sort_by { |booking| [booking.starts_at, booking.id] }
  end

  def visible_bookings
    scope = Booking.where(account: account)
    return scope if administrator?

    scope.where(assignee: user)
  end

  def administrator?
    user.administrator?
  end

  def selected_booking_payload(bookings)
    selected = bookings.find { |booking| booking.id.to_s == params[:booking_id].to_s } || bookings.first
    payload_for(selected) if selected
  end

  def contact_payload(contact)
    {
      id: contact.id,
      name: contact.name.presence || contact.phone_number,
      initials: initials_for(contact.name.presence || contact.phone_number),
      phone_number: contact.phone_number,
      email: contact.email,
      business_name: contact.additional_attributes&.dig('company_name'),
      location: [contact.additional_attributes&.dig('city'), contact.additional_attributes&.dig('country')].compact_blank.join(', ')
    }
  end

  def user_payload(operator)
    return if operator.blank?

    {
      id: operator.id,
      name: operator.name,
      initials: initials_for(operator.name),
      availability_status: operator.availability_status
    }
  end

  def conversation_payload(conversation)
    {
      id: conversation.id,
      display_id: conversation.display_id,
      status: conversation.status,
      control_state: conversation.control_state,
      path: "/app/accounts/#{account.id}/conversations/#{conversation.display_id}"
    }
  end

  def detail_payload(booking)
    {
      preparation_brief: preparation_brief_for(booking),
      strongest_evidence: strongest_evidence_for(booking),
      likely_objection: likely_objection_for(booking),
      suggested_opening_question: suggested_opening_question_for(booking),
      calendar_invitation_sent_at: booking.calendar_invitation_sent_at&.iso8601,
      confirmation_message_id: booking.confirmation_message_id,
      alerts: booking.preparation_alert_deliveries,
      audit_history: audit_history_for(booking)
    }
  end

  def meta_payload(bookings)
    {
      total_count: bookings.length,
      capacity_booked: visible_bookings.where(starts_at: range_start...range_end).confirmed.count,
      capacity_limit: capacity_limit,
      range: {
        from: range_start.iso8601,
        to: range_end.iso8601,
        label: range_label
      },
      visibility: administrator? ? 'admin' : 'operator'
    }
  end

  def filter_options
    {
      statuses: Booking.statuses.keys,
      assignees: account.users.order(:name).map { |operator| user_payload(operator) },
      offers: offers,
      timezones: timezones
    }
  end

  def availability_payload # rubocop:disable Metrics/MethodLength
    result = AiLeadEmployee::BookingAvailabilityService.new(
      account: account,
      from: range_start,
      days: days
    ).perform

    {
      configuration: configuration.slice(
        'connected',
        'provider',
        'calendar_id',
        'timezone',
        'working_days',
        'allowed_hours',
        'duration_minutes',
        'buffer_before_minutes',
        'buffer_after_minutes',
        'minimum_notice_minutes'
      ),
      slots: result.slots.map { |slot| availability_slot_payload(slot) },
      provider_state: configuration['connected'] ? 'connected' : 'failed'
    }
  end

  def availability_slot_payload(slot)
    {
      starts_at: slot.iso8601,
      ends_at: (slot + configuration.fetch('duration_minutes').to_i.minutes).iso8601,
      assignee: account.users.order(:name).first && user_payload(account.users.order(:name).first),
      source: 'business_hours_calendar_rules'
    }
  end

  def calendar_payload(bookings)
    bookings.group_by { |booking| booking.starts_at.in_time_zone(timezone).to_date.iso8601 }.map do |date, day_bookings|
      { date: date, bookings: day_bookings.map { |booking| payload_for(booking) } }
    end
  end

  def range_start
    @range_start ||= Time.zone.parse(params[:from].presence || Time.current.beginning_of_week.iso8601)
  end

  def range_end
    range_start + days.days
  end

  def days
    @days ||= params.fetch(:days, DEFAULT_DAYS).to_i.clamp(1, 31)
  end

  def range_label
    start_date = range_start.in_time_zone(timezone)
    end_date = (range_end - 1.second).in_time_zone(timezone)
    "#{start_date.strftime('%b %-d')} - #{end_date.strftime('%b %-d, %Y')}"
  end

  def timezone
    @timezone ||= ActiveSupport::TimeZone[configuration.fetch('timezone')] || Time.zone
  end

  def capacity_limit
    account.settings&.dig('ai_lead_employee', 'team_capacity_limit').presence || 20
  end

  def call_type_for(booking)
    booking.calendar_event_payload['call_type'].presence || 'product_demo'
  end

  def offer_for(booking)
    booking.qualification_snapshot['offer'].presence ||
      account.settings&.dig('ai_lead_employee', 'default_offer').presence ||
      'Product Demo'
  end

  def booked_channel_for(booking)
    booking.calendar_event_payload['booked_channel'].presence || 'WhatsApp'
  end

  def meeting_link_for(booking)
    booking.calendar_event_payload['meeting_link'].presence || "https://wa.me/#{booking.contact.phone_number.to_s.delete_prefix('+')}"
  end

  def calendar_state_for(booking)
    return booking.calendar_event_payload['calendar_state'] if booking.calendar_event_payload['calendar_state'].present?
    return 'no_invite' if booking.provider_event_id.blank?
    return 'invited' if booking.calendar_invitation_sent_at.blank?

    'confirmed'
  end

  def whatsapp_state_for(booking)
    booking.confirmation_message_id.present? ? 'confirmed' : 'awaiting'
  end

  def preparation_state_for(booking)
    return booking.calendar_event_payload['preparation_state'] if booking.calendar_event_payload['preparation_state'].present?
    return 'not_started' if booking.preparation_alert_deliveries.blank?
    return 'needs_attention' if booking.preparation_alert_deliveries.any? { |delivery| delivery['status'] == 'failed' }

    booking.starts_at < 2.hours.from_now ? 'ready' : 'in_progress'
  end

  def preparation_brief_for(booking)
    booking.calendar_event_payload['preparation_brief'].presence ||
      "Lead requested #{call_type_label(call_type_for(booking)).downcase} for #{offer_for(booking)}. Review the latest conversation before joining."
  end

  def strongest_evidence_for(booking)
    snapshot = booking.qualification_snapshot['evidence'].to_h
    snapshot.slice('problem', 'urgency', 'budget', 'decision_authority').filter_map do |signal, evidence|
      value = evidence['value'].presence || evidence[:value]
      next if value.blank?

      {
        signal: signal,
        value: value
      }
    end
  end

  def likely_objection_for(booking)
    booking.calendar_event_payload['likely_objection'].presence ||
      if booking.qualification_snapshot.dig('evidence', 'budget', 'value').present?
        'Concern about pricing and ROI.'
      else
        'May need clarity on timing or budget.'
      end
  end

  def suggested_opening_question_for(booking)
    booking.calendar_event_payload['suggested_opening_question'].presence ||
      'What would a successful demo and pricing conversation look like for your team?'
  end

  def audit_history_for(booking)
    Audited::Audit.where(auditable: booking).order(created_at: :desc).limit(5).map do |audit|
      {
        action: audit.audited_changes&.dig('ai_lead_employee_action') || audit.action,
        created_at: audit.created_at.iso8601
      }
    end
  end

  def offers
    configured = Array(account.settings&.dig('ai_lead_employee', 'offers')).filter_map { |offer| offer.to_h['name'] || offer.to_s.presence }
    (configured + visible_bookings.map { |booking| offer_for(booking) }).compact_blank.uniq
  end

  def timezones
    (visible_bookings.distinct.pluck(:timezone) + [configuration.fetch('timezone')]).compact_blank.uniq
  end

  def initials_for(value)
    value.to_s.split.first(2).map { |part| part.first&.upcase }.join.presence || 'LD'
  end

  def call_type_label(value)
    value.to_s.tr('_', ' ').titleize
  end
end
