# frozen_string_literal: true

class AiLeadEmployee::BookingProposalService
  class SlotUnavailable < StandardError; end

  class Ineligible < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(code.humanize)
    end
  end

  def initialize(conversation:, qualification:, user:, starts_at:, idempotency_key:, calendar_client: nil) # rubocop:disable Metrics/ParameterLists
    @conversation = conversation
    @qualification = qualification
    @user = user
    @starts_at = starts_at
    @idempotency_key = idempotency_key
    @account = conversation.account
    @configuration = AiLeadEmployee::BookingConfiguration.for(account)
    @calendar_client = calendar_client || AiLeadEmployee::BookingCalendarClient.new(account: account)
  end

  def perform # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    eligibility = AiLeadEmployee::BookingEligibility.new(
      conversation: conversation, qualification: qualification, require_agreement: false
    ).perform
    raise Ineligible, eligibility.failure_code unless eligibility.eligible?
    raise Ineligible, 'calendar_not_connected' unless configuration['calendar_access_configured']

    if (message = existing_message)
      ensure_matching_request!(message)
      return message
    end
    raise SlotUnavailable unless available?

    message = nil
    conversation.reload.with_lock('FOR NO KEY UPDATE') do
      if (message = existing_message)
        ensure_matching_request!(message)
      else
        message = create_message!(eligibility.offer)
      end
    end
    SendReplyJob.perform_later(message.id) if message.whatsapp_outbound_delivery&.pending?
    message
  end

  private

  attr_reader :account, :conversation, :qualification, :user, :starts_at, :idempotency_key, :configuration, :calendar_client

  def available?
    days = [(starts_at.to_date - Time.current.to_date).to_i + 1, 1].max
    result = AiLeadEmployee::BookingAvailabilityService.new(
      account: account, from: Time.current, days: days, calendar_client: calendar_client
    ).perform
    raise Ineligible, result.error_code unless result.provider_state == 'connected'

    result.slots.include?(starts_at)
  end

  def existing_message
    conversation.messages.where(
      "additional_attributes #>> '{ai_lead_employee,booking_proposal,idempotency_key}' = ?", idempotency_key
    ).first
  end

  def ensure_matching_request!(message)
    recorded = message.additional_attributes.dig('ai_lead_employee', 'booking_proposal', 'starts_at')
    raise Ineligible, 'idempotency_key_payload_mismatch' unless Time.zone.parse(recorded) == starts_at
  rescue ArgumentError, TypeError
    raise Ineligible, 'idempotency_key_payload_mismatch'
  end

  def create_message!(offer)
    conversation.messages.create!(
      account: account, inbox: conversation.inbox, sender: user, message_type: :outgoing, content_type: :text,
      content: "Would #{time_label} work for your #{offer.next_step['kind'].humanize.downcase}?",
      additional_attributes: {
        ai_lead_employee: {
          booking_proposal: {
            idempotency_key: idempotency_key, starts_at: starts_at.iso8601,
            ends_at: (starts_at + configuration.fetch('duration_minutes').to_i.minutes).iso8601,
            offer_id: offer.id, offer_configuration_version: offer.configuration_version
          }
        }
      }
    )
  end

  def time_label
    starts_at.in_time_zone(configuration.fetch('timezone')).strftime('%A, %B %-d at %-l:%M %p %Z')
  end
end
