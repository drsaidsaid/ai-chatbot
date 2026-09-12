# frozen_string_literal: true

class AiLeadEmployee::AiReplyUsage < ApplicationRecord
  self.table_name = 'ai_reply_usages'
  CAPACITY_HOLDING_STATUSES = %w[reserved settled partially_delivered].freeze

  belongs_to :account
  belongs_to :ai_subscription, class_name: 'AiLeadEmployee::AiSubscription'
  belongs_to :ai_orchestration_intent, class_name: 'AiLeadEmployee::OrchestrationIntent', inverse_of: :ai_reply_usage
  belongs_to :reconciled_by_platform_app, class_name: 'PlatformApp', optional: true
  has_many :whatsapp_outbound_deliveries, class_name: 'Whatsapp::OutboundDelivery', dependent: :nullify

  enum :status, %w[reserved settled released partially_delivered].index_with(&:itself)
  enum :allowance_source, %w[included top_up].index_with(&:itself)

  scope :capacity_holding, -> { where(status: CAPACITY_HOLDING_STATUSES) }

  validates :reserved_at, :period_started_at, :period_ends_at, presence: true
  validates :ai_orchestration_intent_id, uniqueness: true
  validates :expected_delivery_parts, numericality: { only_integer: true, greater_than: 0 }
  validate :tenant_scope
  validate :valid_period
  validate :terminal_timestamp

  def self.for_delivery(delivery)
    associated_usage = delivery.ai_reply_usage
    return associated_usage if associated_usage&.account_id == delivery.account_id

    usage_id = delivery.message.additional_attributes.dig('ai_lead_employee', 'ai_reply_usage_id')
    find_by(id: usage_id, account_id: delivery.account_id)
  end

  def delivery_failure_code
    return 'customer_allowance_released' if released?
    return 'customer_allowance_reconciliation_required' if partially_delivered?
  end

  private

  def tenant_scope
    return if account_id.blank?

    errors.add(:ai_subscription, 'must belong to the same Business Account') if ai_subscription&.account_id != account_id
    errors.add(:ai_orchestration_intent, 'must belong to the same Business Account') if ai_orchestration_intent&.account_id != account_id
  end

  def valid_period
    return if period_started_at.blank? || period_ends_at.blank? || period_ends_at > period_started_at

    errors.add(:period_ends_at, 'must be after the period start')
  end

  def terminal_timestamp
    errors.add(:settled_at, 'is required for settled usage') if settled? && settled_at.blank?
    errors.add(:released_at, 'is required for released usage') if released? && released_at.blank?
    return unless partially_delivered? && reconciliation_reason.blank?

    errors.add(:reconciliation_reason, 'is required for a partially delivered usage')
  end
end
