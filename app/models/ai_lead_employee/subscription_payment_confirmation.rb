# frozen_string_literal: true

class AiLeadEmployee::SubscriptionPaymentConfirmation < ApplicationRecord
  self.table_name = 'subscription_payment_confirmations'

  belongs_to :account
  belongs_to :ai_subscription_request, class_name: 'AiLeadEmployee::AiSubscriptionRequest'
  belongs_to :confirmed_by_platform_app, class_name: 'PlatformApp'

  validates :payment_reference, :currency, :confirmed_at, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :purpose, inclusion: { in: AiLeadEmployee::AiSubscriptionRequest::PURPOSES }
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :payment_reference, uniqueness: { scope: :account_id }
  validate :request_matches_confirmation

  private

  def request_matches_confirmation
    return if ai_subscription_request.blank?

    errors.add(:ai_subscription_request, 'must belong to the same Business Account') if ai_subscription_request.account_id != account_id
    errors.add(:purpose, 'must match the subscription request') if ai_subscription_request.purpose != purpose
  end
end
