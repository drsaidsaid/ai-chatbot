# frozen_string_literal: true

class AiLeadEmployee::PilotAuthorization < ApplicationRecord
  self.table_name = 'ai_lead_employee_pilot_authorizations'

  EVIDENCE_KINDS = %w[openrouter_key_limit openrouter_guardrail_budget].freeze
  STATUSES = %w[active paused revoked].freeze

  belongs_to :account
  belongs_to :inbox
  belongs_to :contact
  belongs_to :conversation
  belongs_to :ai_provider_connection, class_name: 'AiLeadEmployee::AiProviderConnection'
  belongs_to :authorized_by_platform_app, class_name: 'PlatformApp'

  has_many :orchestration_intents, class_name: 'AiLeadEmployee::OrchestrationIntent', dependent: :restrict_with_exception
  has_many :provider_usages, class_name: 'AiLeadEmployee::AiProviderUsage', dependent: :restrict_with_exception

  enum :status, STATUSES.index_with(&:itself)

  validates :recipient, :provider_limit_verified_at, :starts_at, :expires_at, presence: true
  validates :control_version, :provider_configuration_version,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_attempts, numericality: { only_integer: true, greater_than: 0 }
  validates :max_spend_usd, :provider_limit_usd, numericality: { greater_than: 0 }
  validate :scope_is_consistent
  validate :provider_limit_is_bounded
  validate :provider_evidence_is_concrete

  scope :active_at, lambda { |time|
    active.where('starts_at <= ? AND expires_at > ?', time, time)
  }

  def self.current_for(message:, at: Time.current)
    conversation = message.conversation
    active_at(at).find_by(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      contact_id: conversation.contact_id,
      conversation_id: conversation.id,
      recipient: conversation.contact_inbox&.source_id.to_s,
      control_version: conversation.control_version,
      ai_provider_connection_id: message.account.ai_provider_connection&.id,
      provider_configuration_version: message.account.ai_provider_connection&.configuration_version
    )
  end

  private

  def scope_is_consistent # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return if [inbox, contact, conversation, ai_provider_connection].any?(&:blank?)
    return if inbox.account_id == account_id && contact.account_id == account_id &&
              conversation.account_id == account_id && conversation.inbox_id == inbox_id &&
              conversation.contact_id == contact_id && ai_provider_connection.account_id == account_id

    errors.add(:account, 'must match the authorized Inbox, Lead, Conversation, and provider connection')
  end

  def provider_limit_is_bounded
    return if provider_limit_usd.blank? || max_spend_usd.blank? || provider_limit_usd <= max_spend_usd

    errors.add(:provider_limit_usd, 'must not exceed the owner-funded target')
  end

  def provider_evidence_is_concrete
    evidence = provider_limit_evidence.to_h.stringify_keys
    return if evidence['kind'].in?(EVIDENCE_KINDS) && evidence['key_fingerprint'].present? &&
              evidence['verification_digest'].present?

    errors.add(:provider_limit_evidence, 'must identify a supported verified provider limit without storing credentials')
  end
end
