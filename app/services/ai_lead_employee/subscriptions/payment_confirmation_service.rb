# frozen_string_literal: true

class AiLeadEmployee::Subscriptions::PaymentConfirmationService
  InvalidConfirmation = Class.new(StandardError)

  def initialize(account:, request:, platform_app:, attributes:)
    @account = account
    @request = request
    @platform_app = platform_app
    @payment_reference = attributes[:payment_reference].to_s.strip
    @amount = BigDecimal(attributes[:amount].to_s)
    @currency = attributes[:currency].to_s.upcase
    @confirmed_at = Time.zone.parse(attributes[:confirmed_at].to_s)
    @granted_ai_replies = attributes[:granted_ai_replies]
  rescue ArgumentError
    raise InvalidConfirmation, 'Payment amount or confirmation time is invalid'
  end

  def perform
    raise InvalidConfirmation, 'Confirmation time is required' if confirmed_at.blank?

    account.with_lock do
      existing = AiLeadEmployee::SubscriptionPaymentConfirmation.find_by(account: account, payment_reference: payment_reference)
      return ensure_same_confirmation!(existing) if existing

      request.lock!
      validate_confirmation!
      confirmation = create_confirmation!
      apply_entitlement!
      request.update!(status: :confirmed, confirmed_at: confirmed_at)
      confirmation
    end
  end

  private

  attr_reader :account, :request, :platform_app, :payment_reference, :amount, :currency, :confirmed_at, :granted_ai_replies

  def ensure_same_confirmation!(existing)
    expected = [request.id, amount, currency]
    actual = [existing.ai_subscription_request_id, existing.amount, existing.currency]
    raise InvalidConfirmation, 'Payment reference was already used for different entitlement details' unless expected == actual

    existing
  end

  def validate_confirmation!
    raise InvalidConfirmation, 'Payment reference is required' if payment_reference.blank?
    raise InvalidConfirmation, 'Subscription request belongs to another Business Account' unless request.account_id == account.id
    raise InvalidConfirmation, 'Subscription request is no longer pending' unless request.pending?

    validate_current_entitlement!
    validate_payment_terms!
    validate_top_up_units! if request.purpose == 'top_up'
  end

  def validate_current_entitlement!
    subscription = AiLeadEmployee::AiSubscription.find_by(account_id: account.id)
    return validate_new_subscription!(subscription) if request.purpose == 'new_subscription'

    raise InvalidConfirmation, 'Business Account has no subscription' unless subscription

    validate_subscription_snapshot!(subscription)

    validate_upgrade_state!(subscription) if request.purpose == 'upgrade'
    validate_current_plan_request!(subscription) if request.purpose.in?(%w[renewal top_up])
  end

  def validate_new_subscription!(subscription)
    raise InvalidConfirmation, 'Business Account already has a subscription' if subscription
  end

  def validate_subscription_snapshot!(subscription)
    raise InvalidConfirmation, 'Subscription is not active; create a new payment request after review' unless subscription.active?
    return if subscription.ai_service_plan_id == request.expected_current_plan_id &&
              subscription.updated_at == request.expected_subscription_updated_at

    raise InvalidConfirmation, 'Subscription changed after this request; create a new payment request'
  end

  def validate_upgrade_state!(subscription)
    target = request.ai_service_plan
    valid = target.currency == subscription.ai_service_plan.currency &&
            target.monthly_price > subscription.ai_service_plan.monthly_price &&
            target.included_ai_replies > subscription.included_ai_replies
    return if valid

    raise InvalidConfirmation, 'Approved upgrade no longer increases the current entitlement'
  end

  def validate_current_plan_request!(subscription)
    return if request.ai_service_plan_id == subscription.ai_service_plan_id

    raise InvalidConfirmation, 'Approved renewal or top-up no longer matches the current plan'
  end

  def validate_payment_terms!
    raise InvalidConfirmation, 'Payment currency does not match the approved request' unless request.currency == currency
    return if request.quoted_amount.blank? || request.quoted_amount == amount

    raise InvalidConfirmation, 'Payment amount does not match the approved request'
  end

  def validate_top_up_units!
    return if granted_ai_replies.blank? || granted_ai_replies.to_i == request.requested_ai_replies

    raise InvalidConfirmation, 'Confirmed top-up units do not match the approved package'
  end

  def create_confirmation!
    AiLeadEmployee::SubscriptionPaymentConfirmation.create!(
      account: account,
      ai_subscription_request: request,
      confirmed_by_platform_app: platform_app,
      purpose: request.purpose,
      payment_reference: payment_reference,
      amount: amount,
      currency: currency,
      granted_ai_replies: confirmed_units,
      confirmed_at: confirmed_at
    )
  end

  def apply_entitlement!
    case request.purpose
    when 'new_subscription' then activate_subscription!
    when 'renewal' then renew_subscription!
    when 'upgrade' then upgrade_subscription!
    when 'top_up' then add_top_up!
    end
  end

  def activate_subscription!
    raise InvalidConfirmation, 'Business Account already has a subscription' if AiLeadEmployee::AiSubscription.exists?(account_id: account.id)

    zone = reporting_zone
    period_start = confirmed_at.in_time_zone(zone)
    AiLeadEmployee::AiSubscription.create!(
      account: account,
      ai_service_plan: request.ai_service_plan,
      status: :active,
      reporting_timezone: zone.name,
      period_started_at: period_start.utc,
      renews_at: period_start.advance(months: 1).utc,
      paid_through_at: period_start.advance(months: 1).utc,
      renewal_anchor_day: period_start.day,
      included_ai_replies: request.ai_service_plan.included_ai_replies
    )
  end

  def renew_subscription!
    subscription = required_subscription!
    subscription.with_lock do
      confirmed_at < subscription.renews_at ? prepay_renewal!(subscription) : activate_late_renewal!(subscription)
    end
  end

  def prepay_renewal!(subscription)
    subscription.update!(
      ai_service_plan: request.ai_service_plan, paid_through_at: subscription.billing_boundary_after(subscription.paid_through_at).utc
    )
  end

  def activate_late_renewal!(subscription)
    period_start = confirmed_at.in_time_zone(reporting_zone)
    period_end = period_start.advance(months: 1)
    subscription.update!(
      ai_service_plan: request.ai_service_plan, status: :active, period_started_at: period_start.utc,
      renews_at: period_end.utc, paid_through_at: period_end.utc, renewal_anchor_day: period_start.day,
      included_ai_replies: request.ai_service_plan.included_ai_replies, exhaustion_alerted_at: nil
    )
    subscription.resolve_alerts!
  end

  def upgrade_subscription!
    subscription = required_subscription!
    subscription.with_lock do
      subscription.update!(ai_service_plan: request.ai_service_plan,
                           included_ai_replies: request.ai_service_plan.included_ai_replies, exhaustion_alerted_at: nil)
      rebalance_current_period_top_ups!(subscription)
      subscription.resolve_alerts!
    end
  end

  def add_top_up!
    subscription = required_subscription!
    subscription.with_lock do
      subscription.update!(top_up_ai_replies: subscription.top_up_ai_replies + confirmed_units,
                           exhaustion_alerted_at: nil)
      subscription.resolve_alerts!
    end
  end

  def rebalance_current_period_top_ups!(subscription)
    active = subscription.reply_usages.where(status: %w[reserved settled], period_started_at: subscription.period_started_at)
    available_included = subscription.included_ai_replies - active.included.count
    return unless available_included.positive?

    active.top_up.order(:reserved_at, :id).limit(available_included).each do |usage|
      usage.update!(allowance_source: :included)
    end
  end

  def confirmed_units
    return unless request.purpose == 'top_up'

    request.requested_ai_replies
  end

  def required_subscription!
    AiLeadEmployee::AiSubscription.find_by(account_id: account.id) ||
      raise(InvalidConfirmation, 'Business Account has no subscription')
  end

  def reporting_zone
    timezone = account.reporting_timezone.presence
    (ActiveSupport::TimeZone[timezone] if timezone) || ActiveSupport::TimeZone['UTC']
  end
end
