# frozen_string_literal: true

class AiLeadEmployee::BookingMutationService
  class SlotUnavailable < StandardError; end

  def initialize(account:, user:, booking:, action:, attributes:, idempotency_key:) # rubocop:disable Metrics/ParameterLists
    @account = account
    @user = user
    @booking = booking
    @action = action.to_s
    @attributes = attributes.to_h.with_indifferent_access
    @idempotency_key = idempotency_key.presence || "#{action}-#{booking.id}-#{Time.current.to_i}"
  end

  def perform
    return booking if applied?

    Booking.transaction do
      action == 'cancel' ? cancel! : reschedule!
      remember_mutation!
      audit_mutation!
    end

    send_whatsapp_notice!
    booking.reload
  end

  private

  attr_reader :account, :user, :booking, :action, :attributes, :idempotency_key

  def applied?
    booking.calendar_event_payload.to_h.dig('mutations', idempotency_key).present?
  end

  def reschedule! # rubocop:disable Metrics/AbcSize
    starts_at = Time.zone.parse(attributes.fetch(:starts_at))
    duration = booking.ends_at - booking.starts_at
    raise SlotUnavailable unless slot_available?(starts_at, starts_at + duration)

    booking.assign_attributes(
      starts_at: starts_at,
      ends_at: starts_at + duration,
      status: :confirmed,
      calendar_invitation_sent_at: booking.contact.email.present? ? Time.current : nil
    )
    booking.calendar_event_payload = event_payload.merge(
      'calendar_state' => booking.contact.email.present? ? 'confirmed' : 'invited',
      'rescheduled_at' => Time.current.iso8601,
      'starts_at' => starts_at.iso8601,
      'ends_at' => (starts_at + duration).iso8601
    )
    booking.save!
    booking.lead_qualification.update!(follow_up_state: :call_booked)
  end

  def cancel!
    booking.update!(
      status: :canceled,
      calendar_event_payload: event_payload.merge(
        'calendar_state' => 'canceled',
        'canceled_at' => Time.current.iso8601,
        'cancel_reason' => attributes[:reason].presence || 'Canceled by Human Operator'
      )
    )
    booking.lead_qualification.update!(follow_up_state: :human_review)
  end

  def slot_available?(starts_at, ends_at)
    !Booking.active
            .where(account: account, calendar_id: booking.calendar_id)
            .where.not(id: booking.id)
            .exists?(['starts_at < ? AND ends_at > ?', ends_at, starts_at])
  end

  def remember_mutation!
    current_payload = booking.reload.calendar_event_payload.to_h
    mutations = current_payload.fetch('mutations', {})
    mutations[idempotency_key] = {
      'action' => action,
      'user_id' => user.id,
      'applied_at' => Time.current.iso8601
    }
    booking.update!(calendar_event_payload: current_payload.merge('mutations' => mutations))
  end

  def audit_mutation!
    Audited::Audit.create!(
      auditable: booking,
      associated: account,
      user: user,
      action: 'update',
      audited_changes: {
        'ai_lead_employee_action' => "booking_#{action}",
        'idempotency_key' => idempotency_key,
        'starts_at' => booking.saved_change_to_starts_at,
        'status' => booking.saved_change_to_status
      }.compact,
      version: Audited::Audit.where(auditable: booking).maximum(:version).to_i + 1,
      created_at: Time.current
    )
  end

  def send_whatsapp_notice!
    provider_message_id = text_message_client.send_text!(
      recipient: booking.conversation.contact_inbox.source_id,
      content: notice_text
    )
    Message.create!(
      account: account,
      inbox: booking.conversation.inbox,
      conversation: booking.conversation,
      message_type: :outgoing,
      content_type: :text,
      content: notice_text,
      status: :sent,
      source_id: provider_message_id
    )
    booking.update!(confirmation_message_id: provider_message_id)
  end

  def notice_text
    if action == 'cancel'
      'Your booked call has been canceled. A Human Operator will follow up with next steps.'
    else
      "Your call has been rescheduled for #{booking.starts_at.in_time_zone(booking.timezone).strftime('%A, %B %-d at %-l:%M %p %Z')}."
    end
  end

  def text_message_client
    @text_message_client ||= Meta::Whatsapp::TextMessageClient.new(whatsapp_channel: booking.conversation.inbox.channel)
  end

  def event_payload
    @event_payload ||= booking.calendar_event_payload.to_h
  end
end
