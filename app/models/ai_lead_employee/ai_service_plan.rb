# frozen_string_literal: true

class AiLeadEmployee::AiServicePlan < ApplicationRecord
  self.table_name = 'ai_service_plans'

  STATUSES = %w[draft published archived].freeze

  has_many :subscriptions, class_name: 'AiLeadEmployee::AiSubscription', dependent: :restrict_with_exception
  has_many :subscription_requests, class_name: 'AiLeadEmployee::AiSubscriptionRequest', dependent: :restrict_with_exception

  enum :status, STATUSES.index_with(&:itself)

  validates :code, :name, :currency, :payment_instructions, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :code }
  validates :monthly_price, numericality: { greater_than: 0 }
  validates :included_ai_replies, numericality: { only_integer: true, greater_than: 0 }
  validates :top_up_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :top_up_ai_replies, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validate :complete_top_up_terms
  validate :published_plan_is_immutable, on: :update

  scope :available, -> { published.order(:monthly_price, :id) }

  def publish!
    self.class.transaction do
      versions = self.class.where(code: code).order(:id).lock.to_a
      current = versions.find { |version| version.id == id }
      next current if current.published?

      current.status = :published
      current.published_at = Time.current
      validate_commercial_catalog!(current)
      versions.select { |version| version.id != current.id && version.published? }
              .each { |version| version.update!(status: :archived) }
      current.save!
      current
    end
  end

  private

  def complete_top_up_terms
    return if top_up_price.present? == top_up_ai_replies.present?

    errors.add(:base, 'top-up price and reply allowance must be configured together')
  end

  def validate_commercial_catalog!(current)
    subscribed_plan_ids = AiLeadEmployee::AiSubscription.active.select(:ai_service_plan_id)
    catalog_scope = self.class.where(status: :published).or(self.class.where(id: subscribed_plan_ids))
    catalog = catalog_scope.where.not(id: current.id).to_a + [current]
    return unless catalog.any? { |plan| invalid_top_up_pricing?(plan, catalog) }

    current.errors.add(:base, 'top-up unit price must exceed included unit pricing on every larger plan')
    raise ActiveRecord::RecordInvalid, current
  end

  def invalid_top_up_pricing?(plan, catalog)
    return false unless plan.top_up_price && plan.top_up_ai_replies

    top_up_unit_price = plan.top_up_price / plan.top_up_ai_replies
    catalog.any? do |candidate|
      next false unless candidate.currency == plan.currency
      next false unless candidate.included_ai_replies > plan.included_ai_replies

      top_up_unit_price <= (candidate.monthly_price / candidate.included_ai_replies)
    end
  end

  def published_plan_is_immutable
    return unless status_was.in?(%w[published archived])
    return if changes.keys.all? { |key| %w[status updated_at].include?(key) }

    errors.add(:base, 'published service plan terms are immutable; create a new version')
  end
end
