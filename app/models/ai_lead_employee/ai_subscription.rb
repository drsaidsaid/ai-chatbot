# frozen_string_literal: true

class AiLeadEmployee::AiSubscription < ApplicationRecord
  self.table_name = 'ai_subscriptions'

  belongs_to :account
  belongs_to :ai_service_plan, class_name: 'AiLeadEmployee::AiServicePlan'
  has_many :reply_usages, class_name: 'AiLeadEmployee::AiReplyUsage', dependent: :restrict_with_exception
  has_many :alerts, class_name: 'AiLeadEmployee::AiSubscriptionAlert', dependent: :restrict_with_exception

  enum :status, %w[active canceled review_required].index_with(&:itself)

  validates :reporting_timezone, :period_started_at, :renews_at, :paid_through_at, presence: true
  validates :included_ai_replies, numericality: { only_integer: true, greater_than: 0 }
  validates :top_up_ai_replies, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :renewal_anchor_day, numericality: { only_integer: true, in: 1..31 }
  validate :valid_reporting_timezone
  validate :period_is_forward
  validate :paid_through_current_period

  def roll_period_forward!(at: Time.current)
    return true if at < renews_at
    return false if paid_through_at <= renews_at

    zone = ActiveSupport::TimeZone[reporting_timezone] || ActiveSupport::TimeZone['UTC']
    next_start = period_started_at.in_time_zone(zone)
    next_end = renews_at.in_time_zone(zone)
    while at >= next_end && next_end < paid_through_at
      next_start = next_end
      next_end = billing_boundary_after(next_end, zone)
    end
    if at >= next_end
      update_period!(next_start, next_end)
      return false
    end

    update_period!(next_start, next_end)
    true
  end

  def billing_boundary_after(current_boundary, zone = nil)
    zone ||= ActiveSupport::TimeZone[reporting_timezone] || ActiveSupport::TimeZone['UTC']
    current_boundary = current_boundary.in_time_zone(zone)
    candidate_month = current_boundary.advance(months: 1)
    day = [renewal_anchor_day, candidate_month.end_of_month.day].min
    zone.local(candidate_month.year, candidate_month.month, day,
               current_boundary.hour, current_boundary.min, current_boundary.sec)
  end

  def open_alert!(kind:, at: Time.current)
    alert = alerts.find_or_initialize_by(period_started_at: period_started_at, kind: kind)
    alert.assign_attributes(account: account, status: :open, resolved_at: nil)
    alert.save!
    update!(exhaustion_alerted_at: at) if exhaustion_alerted_at.blank?
    alert
  end

  def resolve_alerts!(kind: nil)
    relation = alerts.open
    relation = relation.where(kind: kind) if kind
    relation.find_each { |alert| alert.update!(status: :resolved, resolved_at: Time.current) }
    update!(exhaustion_alerted_at: nil) unless alerts.open.exists?
  end

  private

  def update_period!(period_start, period_end)
    return if period_started_at == period_start.utc && renews_at == period_end.utc

    resolve_alerts!
    update!(period_started_at: period_start.utc, renews_at: period_end.utc, exhaustion_alerted_at: nil)
  end

  def valid_reporting_timezone
    errors.add(:reporting_timezone, 'is invalid') if reporting_timezone.present? && ActiveSupport::TimeZone[reporting_timezone].blank?
  end

  def period_is_forward
    return if period_started_at.blank? || renews_at.blank? || renews_at > period_started_at

    errors.add(:renews_at, 'must be after the period start')
  end

  def paid_through_current_period
    return if paid_through_at.blank? || renews_at.blank? || paid_through_at >= renews_at

    errors.add(:paid_through_at, 'cannot end before the current period')
  end
end
