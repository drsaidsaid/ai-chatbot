# frozen_string_literal: true

class AiLeadEmployee::AiSubscriptionRequest < ApplicationRecord
  self.table_name = 'ai_subscription_requests'

  PURPOSES = %w[new_subscription renewal upgrade top_up].freeze

  belongs_to :account
  belongs_to :ai_service_plan, class_name: 'AiLeadEmployee::AiServicePlan', optional: true
  belongs_to :expected_current_plan, class_name: 'AiLeadEmployee::AiServicePlan', optional: true
  belongs_to :requested_by, class_name: 'User'
  has_one :payment_confirmation, class_name: 'AiLeadEmployee::SubscriptionPaymentConfirmation', dependent: :restrict_with_exception

  enum :status, %w[pending confirmed canceled].index_with(&:itself)

  validates :purpose, inclusion: { in: PURPOSES }
  validates :payment_instructions, :currency, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :quoted_amount, numericality: { greater_than: 0 }, allow_nil: true
  validates :requested_ai_replies, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :request_scope

  private

  def request_scope
    validate_requester_scope
    validate_plan_scope
    validate_commercial_terms
  end

  def validate_requester_scope
    errors.add(:requested_by, 'must belong to the Business Account') unless AccountUser.exists?(account_id: account_id, user_id: requested_by_id)
  end

  def validate_plan_scope
    errors.add(:ai_service_plan, 'must be published or the current subscribed plan') if ai_service_plan && !valid_plan_state?
    errors.add(:ai_service_plan, 'is required') if ai_service_plan.blank? && purpose != 'top_up'
  end

  def valid_plan_state?
    return true if ai_service_plan.published?
    return false unless purpose.in?(%w[renewal top_up])

    AiLeadEmployee::AiSubscription.exists?(
      account_id: account_id,
      ai_service_plan_id: ai_service_plan_id
    )
  end

  def validate_commercial_terms
    errors.add(:quoted_amount, 'is required') if quoted_amount.blank?
    top_up_terms_match = requested_ai_replies.present? == (purpose == 'top_up')
    errors.add(:requested_ai_replies, 'must be present only for a top-up') unless top_up_terms_match
  end
end
