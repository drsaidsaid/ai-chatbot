# frozen_string_literal: true

class Api::V1::Accounts::BookingsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: AiLeadEmployee::BookingsWorkspaceService.new(
      account: current_account,
      user: current_user,
      params: params.permit(:from, :days, :status, :assignee_id, :offer, :timezone, :booking_id)
    ).perform
  end

  def available_slots
    service = AiLeadEmployee::BookingAvailabilityService.new(
      account: current_account,
      from: availability_from,
      days: params.fetch(:days, 7)
    ).perform

    render json: {
      slots: service.slots.map(&:iso8601),
      availability: AiLeadEmployee::BookingsWorkspaceService.new(
        account: current_account,
        user: current_user,
        params: params.permit(:from, :days)
      ).perform.fetch(:availability)
    }
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

  def reschedule
    booking = mutate_booking('reschedule', reschedule_params)
    render json: booking_payload(booking)
  rescue AiLeadEmployee::BookingMutationService::SlotUnavailable
    render json: { error: 'Selected slot is unavailable' }, status: :conflict
  end

  def cancel
    booking = mutate_booking('cancel', cancel_params)
    render json: booking_payload(booking)
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

  def mutate_booking(action, attributes)
    AiLeadEmployee::BookingMutationService.new(
      account: current_account,
      user: current_user,
      booking: visible_booking_scope.find(params.require(:id)),
      action: action,
      attributes: attributes,
      idempotency_key: params[:idempotency_key]
    ).perform
  end

  def visible_booking_scope
    scope = Booking.where(account: current_account)
    return scope if current_user.administrator?

    scope.where(assignee: current_user)
  end

  def reschedule_params
    params.permit(:starts_at)
  end

  def cancel_params
    params.permit(:reason)
  end

  def booking_payload(booking)
    AiLeadEmployee::BookingsWorkspaceService.new(
      account: current_account,
      user: current_user,
      params: { booking_id: booking.id }
    ).payload_for(booking)
  end
end
