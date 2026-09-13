# frozen_string_literal: true

class AiLeadEmployee::AiSubscriptionAlert < ApplicationRecord
  self.table_name = 'ai_subscription_alerts'

  belongs_to :account
  belongs_to :ai_subscription, class_name: 'AiLeadEmployee::AiSubscription'

  enum :kind, %w[allowance_exhausted subscription_renewal_due].index_with(&:itself)
  enum :status, %w[open resolved].index_with(&:itself)

  validates :period_started_at, presence: true
  validates :kind, uniqueness: { scope: %i[ai_subscription_id period_started_at] }
  validate :tenant_scope

  after_commit :enqueue_delivery, if: :delivery_required?

  private

  def enqueue_delivery
    AiLeadEmployee::SubscriptionAlertDeliveryJob.perform_later(self)
  end

  def delivery_required?
    previously_new_record? || (saved_change_to_status? && open?)
  end

  def tenant_scope
    return if account_id.blank?

    errors.add(:ai_subscription, 'must belong to the same Business Account') if ai_subscription&.account_id != account_id
  end
end
