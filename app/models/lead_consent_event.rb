# frozen_string_literal: true

class LeadConsentEvent < ApplicationRecord
  KINDS = %w[withdrawn granted].freeze
  PURPOSES = %w[automated_contact].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :conversation
  belongs_to :message
  belongs_to :whatsapp_webhook_event, class_name: 'Whatsapp::WebhookEvent'
  belongs_to :actor, polymorphic: true

  validates :event_kind, inclusion: { in: KINDS }
  validates :purpose, inclusion: { in: PURPOSES }
  validates :reason, :evidence_text, :recognizer_version, :occurred_at, :recorded_at, presence: true
  validates :message_id, uniqueness: { scope: [:account_id, :purpose] }
  validate :account_scope_is_consistent
  validate :source_is_verified_inbound_message
  validate :actor_is_valid_for_event_kind
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

  def account_scope_is_consistent
    %i[contact conversation message whatsapp_webhook_event].each do |association|
      record = public_send(association)
      errors.add(association, 'must belong to the same account') unless record&.account_id == account_id
    end
  end

  def source_is_verified_inbound_message
    return if verified_source_message?

    errors.add(:message, 'must be the verified Lead-authored inbound source')
  end

  def verified_source_message?
    inbound_message_matches? && conversation_matches? && provider_event_matches?
  end

  def inbound_message_matches?
    message&.incoming? && message.sender == contact && message.conversation_id == conversation_id
  end

  def conversation_matches?
    conversation&.contact_id == contact_id && message&.inbox_id == whatsapp_webhook_event&.inbox_id
  end

  def provider_event_matches?
    return false unless message && whatsapp_webhook_event

    AiLeadEmployee::AutomatedContactConsent
      .verified_event_scope_for(message, include_in_flight: true)
      .exists?(id: whatsapp_webhook_event.id)
  end

  def actor_is_valid_for_event_kind
    return if event_kind == 'withdrawn' && actor == contact
    return if event_kind == 'granted' && actor.is_a?(User) &&
              AccountUser.exists?(account_id: account_id, user_id: actor.id, role: :administrator)

    errors.add(:actor, 'must be the Lead for withdrawal or an account administrator for re-consent')
  end

  def prevent_mutation
    errors.add(:base, 'Consent evidence is immutable')
    throw(:abort)
  end
end
