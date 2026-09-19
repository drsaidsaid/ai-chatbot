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
    result = AiLeadEmployee::BookingAvailabilityService.new(
      account: current_account,
      from: availability_from,
      days: params.fetch(:days, 7)
    ).perform

    render json: {
      slots: result.slots.map(&:iso8601),
      provider_state: result.provider_state,
      error_code: result.error_code,
      configuration: AiLeadEmployee::BookingConfiguration.for(current_account).merge(
        'connected' => result.provider_state == 'connected'
      )
    }
  end

  def create
    result = AiLeadEmployee::BookingService.new(
      conversation: conversation,
      qualification: lead_qualification,
      starts_at: parsed_time(:starts_at),
      agreed_starts_at: parsed_time(:agreed_starts_at),
      agreement_message: agreement_message,
      attendee_email: voluntary_attendee_email,
      idempotency_key: params.require(:idempotency_key)
    ).perform

    render json: booking_payload(result.booking), status: result.created ? :created : :ok
  rescue AiLeadEmployee::BookingService::SlotUnavailable
    render json: { error: 'Selected slot is unavailable' }, status: :conflict
  rescue AiLeadEmployee::BookingService::Ineligible => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  rescue AiLeadEmployee::BookingService::ProviderUnknown => e
    render json: booking_payload(e.booking).merge(error: e.message, code: 'provider_result_unknown'), status: :accepted
  end

  def propose
    message = AiLeadEmployee::BookingProposalService.new(
      conversation: conversation, qualification: lead_qualification, user: current_user,
      starts_at: parsed_time(:starts_at), idempotency_key: params.require(:idempotency_key)
    ).perform
    render json: { message_id: message.id, starts_at: message.additional_attributes.dig('ai_lead_employee', 'booking_proposal', 'starts_at') },
           status: :created
  rescue AiLeadEmployee::BookingProposalService::Ineligible => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  rescue AiLeadEmployee::BookingProposalService::SlotUnavailable
    render json: { error: 'Selected slot is unavailable' }, status: :conflict
  end

  def reschedule
    booking = mutate_booking('reschedule', reschedule_params)
    render json: booking_payload(booking)
  rescue AiLeadEmployee::BookingMutationService::SlotUnavailable
    render json: { error: 'Selected slot is unavailable' }, status: :conflict
  rescue AiLeadEmployee::BookingMutationService::ProviderRejected => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  rescue AiLeadEmployee::BookingMutationService::ProviderUnknown => e
    render json: booking_payload(e.booking).merge(error: e.message, code: 'provider_result_unknown'), status: :accepted
  end

  def cancel
    booking = mutate_booking('cancel', cancel_params)
    render json: booking_payload(booking)
  end

  def reconcile
    booking = AiLeadEmployee::BookingReconciliationService.new(
      account: current_account, user: current_user, booking: visible_booking_scope.find(params.require(:id))
    ).perform
    render json: booking_payload(booking)
  rescue AiLeadEmployee::BookingService::ProviderUnknown, AiLeadEmployee::BookingMutationService::ProviderUnknown => e
    render json: booking_payload(e.booking).merge(error: e.message, code: 'provider_result_unknown'), status: :accepted
  rescue AiLeadEmployee::BookingService::Ineligible, AiLeadEmployee::BookingMutationService::ProviderRejected => e
    render json: { error: e.message, code: e.code }, status: :unprocessable_entity
  end

  rescue_from AiLeadEmployee::BookingMutationService::ProviderRejected do |error|
    render json: { error: error.message, code: error.code }, status: :unprocessable_entity
  end

  rescue_from AiLeadEmployee::BookingMutationService::ProviderUnknown do |error|
    render json: booking_payload(error.booking).merge(error: error.message, code: 'provider_result_unknown'), status: :accepted
  end

  private

  def conversation
    @conversation ||= policy_scope(current_account.conversations).find(params.require(:conversation_id))
  end

  def lead_qualification
    access = AiLeadEmployee::AccessScope.new(account: current_account, user: current_user)
    raise Pundit::NotAuthorizedError unless access.complete_contact?(conversation.contact)

    @lead_qualification ||= LeadQualification.where(
      account: current_account, contact: conversation.contact, offer: conversation.offer
    ).order(last_evaluated_at: :desc, id: :desc).first || configured_offer_qualification
  end

  def configured_offer_qualification
    return unless conversation.offer&.qualification_enabled?

    AiLeadEmployee::QualificationService.new(conversation: conversation).perform.qualification
  end

  def agreement_message
    @agreement_message ||= conversation.messages.incoming.find(params.require(:agreement_message_id))
  end

  def voluntary_attendee_email
    return unless ActiveModel::Type::Boolean.new.cast(params[:attendee_email_voluntarily_supplied])

    params.require(:attendee_email)
  end

  def availability_from
    params[:from].present? ? parsed_time(:from) : Time.current
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
    policy_scope(Booking.where(account: current_account))
  end

  def reschedule_params
    { starts_at: parsed_time(:starts_at).iso8601 }
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

  def parsed_time(key)
    Time.iso8601(params.require(key).to_s)
  rescue ArgumentError
    raise ActionController::BadRequest, "Invalid #{key}"
  end
end
