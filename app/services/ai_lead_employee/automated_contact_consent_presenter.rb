# frozen_string_literal: true

class AiLeadEmployee::AutomatedContactConsentPresenter
  def initialize(account:, user:, contact:, include_reconsent_candidate: false, preloaded: nil)
    @account = account
    @user = user
    @contact = contact
    @access = AiLeadEmployee::AccessScope.new(account: account, user: user)
    @include_reconsent_candidate = include_reconsent_candidate
    @preloaded = preloaded
  end

  def payload
    active_stop = preloaded ? preloaded[:active_stop] : active_stop_record
    return legacy_active_payload(active_stop) if active_stop && active_stop.consent_event.blank?

    latest_event = current_event(active_stop)
    return base_payload('unknown') unless latest_event

    event_payload(active_stop, latest_event)
  end

  private

  attr_reader :account, :user, :contact, :access, :preloaded

  def current_event(active_stop)
    return active_stop.consent_event if active_stop
    return preloaded[:latest_event] if preloaded

    latest_consent_event
  end

  def event_payload(active_stop, latest_event)
    base_payload(active_stop ? 'withdrawn' : latest_event.event_kind).merge(
      reason: latest_event.reason,
      evidence: evidence_payload(latest_event),
      reconsent_candidate: reconsent_candidate_payload(active_stop)
    ).compact
  end

  def active_stop_record
    LeadFollowUpOptOut.includes(:consent_event).find_by(account: account, contact: contact)
  end

  def base_payload(state)
    { state: state, purpose: AiLeadEmployee::AutomatedContactConsent::PURPOSE }
  end

  def latest_consent_event
    LeadConsentEvent.where(account: account, contact: contact, purpose: AiLeadEmployee::AutomatedContactConsent::PURPOSE)
                    .order(occurred_at: :desc, id: :desc)
                    .first
  end

  def legacy_active_payload(active_stop)
    base_payload('withdrawn').merge(
      reason: active_stop.reason,
      evidence: legacy_evidence_payload(active_stop),
      reconsent_candidate: reconsent_candidate_payload(active_stop)
    ).compact
  end

  def legacy_evidence_payload(active_stop)
    return unless evidence_visible_for_conversation?(active_stop.conversation_id)

    { legacy: true, occurred_at: active_stop.opted_out_at&.iso8601 }
  end

  def evidence_payload(event)
    return unless evidence_visible?(event)

    {
      id: event.id,
      source_message_id: event.message_id,
      source_conversation_id: event.conversation_id,
      text: event.evidence_text,
      occurred_at: event.occurred_at&.iso8601,
      recorded_at: event.recorded_at&.iso8601,
      recognizer_version: event.recognizer_version,
      actor_type: event.actor_type
    }
  end

  def evidence_visible?(event)
    evidence_visible_for_conversation?(event.conversation_id)
  end

  def evidence_visible_for_conversation?(conversation_id)
    return preloaded[:visible_conversation_ids].include?(conversation_id) if preloaded

    access.administrator? || access.conversations.exists?(id: conversation_id)
  end

  def reconsent_candidate_payload(active_stop)
    return unless reconsent_candidate_visible?(active_stop)

    message = if preloaded
                preloaded[:reconsent_candidate]
              else
                verified_inbound_messages
                  .where(
                    'COALESCE(messages.provider_created_at, messages.created_at) > ?',
                    consent_service.withdrawal_time(active_stop)
                  )
                  .reorder(provider_created_at: :desc, id: :desc)
                  .find { |item| AiLeadEmployee::AutomatedContactConsent.explicit_grant?(item.content) }
              end
    return unless message

    {
      source_message_id: message.id,
      expected_event_id: consent_service.withdrawal_token(active_stop),
      text: message.content,
      occurred_at: (message.provider_created_at || message.created_at)&.iso8601
    }
  end

  def reconsent_candidate_visible?(active_stop)
    administrator = preloaded ? preloaded[:administrator] : access.administrator?
    [@include_reconsent_candidate, active_stop.present?, administrator].all?
  end

  def consent_service
    AiLeadEmployee::AutomatedContactConsent
  end

  def verified_inbound_messages
    AiLeadEmployee::AutomatedContactConsent.verified_inbound_messages(
      account: account,
      contact_ids: [contact.id]
    )
  end
end
