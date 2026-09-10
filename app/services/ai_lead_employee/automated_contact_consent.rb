# frozen_string_literal: true

class AiLeadEmployee::AutomatedContactConsent
  PURPOSE = 'automated_contact'
  RECOGNIZER_VERSION = 'r05-v1'
  STOP_REASON = 'lead_requested_stop'
  GRANT_REASON = 'administrator_recorded_explicit_reconsent'

  Result = Struct.new(:event, :stopped, keyword_init: true) do
    def stopped? = stopped
  end

  def self.record_inbound!(message:, webhook_event:)
    new(message: message, webhook_event: webhook_event).record_inbound!
  end

  def self.grant!(contact:, source_message:, expected_event_id:, actor:)
    new(message: source_message, webhook_event: verified_event_for(source_message)).grant!(
      contact: contact,
      expected_event_id: expected_event_id,
      actor: actor
    )
  end

  def self.explicit_grant?(text)
    AiLeadEmployee::AutomatedContactConsentRecognizer.explicit_grant?(text)
  end

  def self.withdrawal?(text)
    AiLeadEmployee::AutomatedContactConsentRecognizer.withdrawal?(text)
  end

  def self.verified_event_for(message)
    return unless message

    verified_event_scope_for(message).first
  end

  def self.verified_event_scope_for(message, include_in_flight: false)
    states = include_in_flight ? %w[pending processed] : %w[processed]
    Whatsapp::WebhookEvent.where(state: states).where(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      provider_message_id: message.source_id,
      kind: 'messages'
    )
  end

  def self.verified_inbound_messages(account:, contact_ids:)
    Message.incoming.where(account: account, sender_type: 'Contact', sender_id: contact_ids).where(
      <<~SQL.squish
        EXISTS (
          SELECT 1 FROM whatsapp_webhook_events
          WHERE whatsapp_webhook_events.account_id = messages.account_id
            AND whatsapp_webhook_events.inbox_id = messages.inbox_id
            AND whatsapp_webhook_events.provider_message_id = messages.source_id
            AND whatsapp_webhook_events.kind = 'messages'
            AND whatsapp_webhook_events.state = #{Whatsapp::WebhookEvent.states.fetch('processed')}
        )
      SQL
    )
  end

  def self.withdrawal_token(active_stop) = active_stop.consent_event_id || "legacy:#{active_stop.id}:#{active_stop.updated_at.to_i}"
  def self.withdrawal_time(active_stop) = active_stop.consent_event&.occurred_at || active_stop.opted_out_at

  def initialize(message:, webhook_event:)
    @message = message
    @webhook_event = webhook_event
  end

  def record_inbound!
    return Result.new(stopped: active_stop?) unless trusted_source?
    return Result.new(stopped: active_stop?) unless withdrawal?

    ApplicationRecord.transaction do
      channel.lock!
      existing_event = LeadConsentEvent.find_by(account: account, purpose: PURPOSE, message: message)
      next Result.new(event: existing_event, stopped: true) if existing_event

      conversations = owned_conversations.lock('FOR NO KEY UPDATE').order(:id).to_a
      event = record_withdrawal_event!
      permission_changed = apply_current_permission!
      invalidate_automation!(conversations) if permission_changed

      Result.new(event: event, stopped: true)
    end
  end

  def grant!(contact:, expected_event_id:, actor:)
    @grant_contact = contact
    raise ArgumentError, 'Verified explicit re-consent evidence is required' unless trusted_grant_source?
    raise ArgumentError, 'Only an account administrator can record re-consent' unless administrator?(actor)

    ApplicationRecord.transaction do
      channel.lock!
      conversations = owned_conversations.lock('FOR NO KEY UPDATE').order(:id).to_a
      active_stop = LeadFollowUpOptOut.lock.find_by(account: account, contact: contact)
      raise ActiveRecord::RecordNotFound, 'No active automated-contact withdrawal' if active_stop.blank?

      raise ArgumentError, 'The active withdrawal changed; reload and try again' unless expected_withdrawal_matches?(active_stop, expected_event_id)
      raise ArgumentError, 'Re-consent evidence must be newer than the withdrawal' unless newer_than?(active_stop)

      event = record_grant_event!(contact: contact, actor: actor)
      active_stop.destroy!
      invalidate_automation!(conversations)
      Result.new(event: event, stopped: false)
    end
  end

  private

  attr_reader :message, :webhook_event

  def trusted_source?
    trusted_message? && trusted_webhook_event?
  end

  def trusted_message?
    message&.persisted? && message.incoming? && message.sender == contact
  end

  def trusted_webhook_event?
    webhook_event.present? && self.class.verified_event_scope_for(message, include_in_flight: true).exists?(id: webhook_event.id)
  end

  def withdrawal? = self.class.withdrawal?(message.content)

  def record_withdrawal_event!
    record_event!(event_kind: 'withdrawn', reason: STOP_REASON, actor: contact)
  end

  def record_grant_event!(contact:, actor:)
    record_event!(event_kind: 'granted', reason: GRANT_REASON, actor: actor, contact: contact)
  end

  def record_event!(event_kind:, reason:, actor:, contact: self.contact)
    LeadConsentEvent.create!(
      account: account,
      contact: contact,
      conversation: message.conversation,
      message: message,
      whatsapp_webhook_event: webhook_event,
      event_kind: event_kind,
      purpose: PURPOSE,
      reason: reason,
      evidence_text: message.content,
      recognizer_version: RECOGNIZER_VERSION,
      actor: actor,
      occurred_at: message.provider_created_at || message.created_at,
      recorded_at: Time.current
    )
  end

  def apply_current_permission!
    latest_event = LeadConsentEvent.where(account: account, contact: contact, purpose: PURPOSE)
                                   .order(occurred_at: :desc, id: :desc)
                                   .first
    return false unless latest_event&.event_kind == 'withdrawn'

    stop = LeadFollowUpOptOut.find_or_initialize_by(account: account, contact: contact)
    return false if stop.consent_event_id == latest_event.id

    stop.update!(
      conversation: latest_event.conversation,
      message: latest_event.message,
      consent_event: latest_event,
      reason: STOP_REASON,
      opted_out_at: latest_event.occurred_at
    )
    true
  end

  def invalidate_automation!(conversations)
    conversations.each do |conversation|
      conversation.update!(control_version: conversation.control_version + 1)
      Conversations::ControlService.invalidate_pending_ai!(conversation: conversation, reason: 'opted_out')
    end
  end

  def active_stop?
    LeadFollowUpOptOut.exists?(account: account, contact: contact)
  end

  def trusted_grant_source?
    message&.persisted? && message.incoming? && message.sender == @grant_contact &&
      trusted_source? && self.class.explicit_grant?(message.content)
  end

  def administrator?(actor)
    actor.is_a?(User) && AccountUser.exists?(account: account, user: actor, role: :administrator)
  end

  def newer_than?(active_stop)
    (message.provider_created_at || message.created_at) > self.class.withdrawal_time(active_stop)
  end

  def expected_withdrawal_matches?(active_stop, expected)
    expected.to_s == self.class.withdrawal_token(active_stop).to_s
  end

  def owned_conversations
    account.conversations.where(contact: contact)
  end

  def channel = message.inbox.channel
  def account = message.account
  def contact = message.sender
end
