# frozen_string_literal: true

class AiLeadEmployee::Subscriptions::RequestService
  InvalidRequest = Class.new(StandardError)

  def initialize(account:, requested_by:, plan:, purpose:)
    @account = account
    @requested_by = requested_by
    @plan = plan
    @purpose = purpose.to_s
  end

  def perform
    raise InvalidRequest, 'The selected plan is not available' unless plan_available?

    account.with_lock do
      validate_purpose!
      AiLeadEmployee::AiSubscriptionRequest.create!(
        account: account,
        ai_service_plan: plan,
        expected_current_plan: @subscription&.ai_service_plan,
        expected_subscription_updated_at: @subscription&.updated_at,
        requested_by: requested_by,
        purpose: purpose,
        quoted_amount: quoted_amount,
        currency: plan.currency,
        requested_ai_replies: normalized_requested_units,
        payment_instructions: plan.payment_instructions
      )
    end
  end

  private

  attr_reader :account, :requested_by, :plan, :purpose

  def plan_available?
    return false unless plan
    return true if plan.published?
    return false unless purpose.in?(%w[renewal top_up])

    AiLeadEmployee::AiSubscription.exists?(account_id: account.id, ai_service_plan_id: plan.id)
  end

  def validate_purpose!
    @subscription = AiLeadEmployee::AiSubscription.find_by(account_id: account.id)
    validate_subscription_presence!(@subscription)
    validate_upgrade!(@subscription) if purpose == 'upgrade'
    validate_renewal!(@subscription) if purpose == 'renewal'
    validate_top_up! if purpose == 'top_up'
  end

  def validate_subscription_presence!(subscription)
    missing_existing_subscription = subscription.blank? && purpose != 'new_subscription'
    raise InvalidRequest, 'Choose new subscription for an account without an active plan' if missing_existing_subscription

    raise InvalidRequest, 'This Business Account already has a subscription' if subscription.present? && purpose == 'new_subscription'
    return if subscription.blank? || subscription.active?

    raise InvalidRequest, 'Subscription is not active; contact the Platform Operator before requesting payment'
  end

  def validate_upgrade!(subscription)
    allowance_increases = plan.included_ai_replies > subscription.included_ai_replies
    price_increases = plan.monthly_price > subscription.ai_service_plan.monthly_price
    currency_matches = plan.currency == subscription.ai_service_plan.currency
    return if allowance_increases && price_increases && currency_matches

    raise InvalidRequest, 'An upgrade must keep currency and increase both the allowance and monthly price'
  end

  def validate_top_up!
    return if plan.top_up_price.present? && plan.top_up_ai_replies.present?

    raise InvalidRequest, 'This plan does not have an approved top-up package'
  end

  def validate_renewal!(subscription)
    return if plan.id == subscription.ai_service_plan_id

    raise InvalidRequest, 'A renewal must use the current plan; request an upgrade to change plans'
  end

  def quoted_amount
    return plan.top_up_price if purpose == 'top_up'
    return plan.monthly_price unless purpose == 'upgrade'

    current_price = @subscription.ai_service_plan.monthly_price
    [plan.monthly_price - current_price, 0].max
  end

  def normalized_requested_units
    plan.top_up_ai_replies if purpose == 'top_up'
  end
end
