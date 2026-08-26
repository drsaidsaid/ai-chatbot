# frozen_string_literal: true

class Api::V1::Accounts::BookingsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: Booking.where(account: current_account).order(starts_at: :asc).map { |booking| booking_payload(booking) }
  end

  def available_slots
    slots = AiLeadEmployee::BookingAvailabilityService.new(
      account: current_account,
      from: availability_from,
      days: params.fetch(:days, 7)
    ).perform.slots

    render json: { slots: slots.map(&:iso8601) }
  end

  def create
    result = AiLeadEmployee::BookingService.new(
      conversation: conversation,
      qualification: lead_qualification,
      starts_at: Time.zone.parse(params.require(:starts_at)),
      idempotency_key: params.require(:idempotency_key)
    ).perform

    render json: booking_payload(result.booking), status: result.created ? :created : :ok
  rescue AiLeadEmployee::BookingService::SlotUnavailable
    render json: { error: 'Selected slot is unavailable' }, status: :conflict
  rescue AiLeadEmployee::BookingService::NotHighlyQualified
    render json: { error: 'Lead must be Highly Qualified before booking' }, status: :unprocessable_entity
  end

  private

  def conversation
    @conversation ||= current_account.conversations.find(params.require(:conversation_id))
  end

  def lead_qualification
    @lead_qualification ||= conversation.contact.lead_qualification ||
                            AiLeadEmployee::QualificationService.new(conversation: conversation).perform.qualification
  end

  def availability_from
    params[:from].present? ? Time.zone.parse(params[:from]) : Time.current
  end

  def booking_payload(booking)
    {
      id: booking.id,
      contact_id: booking.contact_id,
      conversation_id: booking.conversation_id,
      lead_qualification_id: booking.lead_qualification_id,
      assignee_id: booking.assignee_id,
      status: booking.status,
      calendar_id: booking.calendar_id,
      provider: booking.provider,
      provider_event_id: booking.provider_event_id,
      starts_at: booking.starts_at.iso8601,
      ends_at: booking.ends_at.iso8601,
      timezone: booking.timezone,
      qualification_evidence_ids: booking.qualification_evidence_ids,
      confirmation_message_id: booking.confirmation_message_id,
      calendar_invitation_sent_at: booking.calendar_invitation_sent_at&.iso8601,
      preparation_alert_recipients: booking.preparation_alert_recipients
    }
  end
end
