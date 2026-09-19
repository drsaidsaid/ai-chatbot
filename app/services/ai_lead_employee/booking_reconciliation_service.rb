# frozen_string_literal: true

class AiLeadEmployee::BookingReconciliationService
  def initialize(account:, user:, booking:, calendar_client: nil)
    @account = account
    @user = user
    @booking = booking
    @calendar_client = calendar_client
  end

  def perform
    action = booking.provider_operation['action']
    return reconcile_create if action == 'create'
    return reconcile_mutation(action) if action.in?(%w[reschedule cancel])

    raise AiLeadEmployee::BookingService::Ineligible, 'provider_operation_missing'
  end

  private

  attr_reader :account, :user, :booking, :calendar_client

  def reconcile_create
    AiLeadEmployee::BookingService.new(
      conversation: booking.conversation, qualification: booking.lead_qualification,
      starts_at: booking.starts_at, agreed_starts_at: booking.starts_at,
      agreement_message: booking.agreement_message, attendee_email: booking.attendee_email,
      idempotency_key: booking.idempotency_key, calendar_client: calendar_client
    ).reconcile_unknown!(booking).booking
  end

  def reconcile_mutation(action)
    operation = booking.provider_operation
    AiLeadEmployee::BookingMutationService.new(
      account: account, user: user, booking: booking, action: action,
      attributes: { starts_at: operation['starts_at'], reason: operation['reason'] }.compact,
      idempotency_key: operation.fetch('idempotency_key', operation_key), calendar_client: calendar_client
    ).reconcile_unknown!
  end

  def operation_key
    booking.calendar_event_payload.to_h.fetch('mutations', {}).find do |_key, mutation|
      mutation['state'] == 'unknown' && mutation['action'] == booking.provider_operation['action']
    end&.first || raise(AiLeadEmployee::BookingService::Ineligible, 'provider_operation_missing')
  end
end
