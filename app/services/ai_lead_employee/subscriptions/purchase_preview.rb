# frozen_string_literal: true

class AiLeadEmployee::Subscriptions::PurchasePreview
  InvalidPreview = Class.new(StandardError)
  SIGNED_FIELDS = %i[
    purpose plan_id amount_due currency requested_ai_replies used_ai_replies awaiting_delivery_ai_replies
    current_remaining_ai_replies resulting_included_ai_replies resulting_included_ai_replies_remaining
    resulting_top_up_ai_replies_remaining resulting_ai_replies_remaining renews_at
  ].freeze

  class << self
    def signature_for(account:, preview:)
      verifier.generate(signature_payload(account, preview), expires_in: 30.minutes)
    end

    def signature_valid?(signature, account:, preview:)
      verifier.verified(signature) == signature_payload(account, preview)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      false
    end

    private

    def signature_payload(account, preview)
      values = SIGNED_FIELDS.index_with { |field| canonical_value(preview[field]) }
      { account_id: account.id, values: values }
    end

    def canonical_value(value)
      return value.utc.iso8601(6) if value.respond_to?(:iso8601)
      return value.to_s('F') if value.is_a?(BigDecimal)

      value
    end

    def verifier
      Rails.application.message_verifier('ai-subscription-purchase-preview')
    end
  end

  def initialize(account:, plan:, purpose:, at: Time.current)
    @account = account
    @plan = plan
    @purpose = purpose.to_s
    @at = at
  end

  def perform
    account.with_lock do
      subscription = AiLeadEmployee::AiSubscription.find_by(account_id: account.id)
      subscription&.lock!
      validate!(subscription)
      preview = build_preview(subscription)
      yield(preview, subscription) if block_given?
      preview
    end
  end

  private

  attr_reader :account, :plan, :purpose, :at

  def validate!(subscription)
    validate_purpose!
    validate_plan!(subscription)
    validate_subscription_presence!(subscription)
    return if subscription.blank?

    validate_subscription!(subscription)
    validate_upgrade!(subscription) if purpose == 'upgrade'
    validate_renewal!(subscription) if purpose == 'renewal'
    validate_top_up!(subscription) if purpose == 'top_up'
  end

  def validate_purpose!
    return if purpose.in?(AiLeadEmployee::AiSubscriptionRequest::PURPOSES)

    raise InvalidPreview, 'The selected purchase type is not available'
  end

  def validate_plan!(subscription)
    raise InvalidPreview, 'The selected plan is not available' unless plan_available?(subscription)
  end

  def validate_subscription!(subscription)
    raise InvalidPreview, 'Subscription is not active; contact the Platform Operator before requesting payment' unless subscription.active?
    return if subscription.roll_period_forward!(at: at) || !purpose.in?(%w[top_up upgrade])

    raise InvalidPreview, 'Renew the subscription first. Purchased extras remain recorded while AI replies are paused.'
  end

  def plan_available?(subscription)
    return false unless plan
    return true if plan.published?

    purpose.in?(%w[renewal top_up]) && subscription&.ai_service_plan_id == plan.id
  end

  def validate_subscription_presence!(subscription)
    raise InvalidPreview, 'Choose new subscription for an account without an active plan' if subscription.blank? && purpose != 'new_subscription'
    return unless subscription.present? && purpose == 'new_subscription'

    raise InvalidPreview, 'This Business Account already has a subscription'
  end

  def validate_upgrade!(subscription)
    allowance_increases = plan.included_ai_replies > subscription.included_ai_replies
    price_increases = plan.monthly_price > subscription.ai_service_plan.monthly_price
    currency_matches = plan.currency == subscription.ai_service_plan.currency
    return if allowance_increases && price_increases && currency_matches

    detail = currency_matches ? 'increase both the allowance and monthly price' : 'keep currency and increase both the allowance and monthly price'
    raise InvalidPreview, "An upgrade must #{detail}"
  end

  def validate_renewal!(subscription)
    return if plan.id == subscription.ai_service_plan_id

    raise InvalidPreview, 'A renewal must use the current plan; request an upgrade to change plans'
  end

  def validate_top_up!(subscription)
    raise InvalidPreview, 'A top-up must use the current plan; request an upgrade to change plans' unless plan.id == subscription.ai_service_plan_id
    return if plan.top_up_price.present? && plan.top_up_ai_replies.present?

    raise InvalidPreview, 'This plan does not have an approved top-up package'
  end

  def build_preview(subscription)
    purchase_balance(subscription).merge(
      purpose: purpose,
      plan_id: plan.id,
      plan_name: plan.name,
      current_plan_name: subscription&.ai_service_plan&.name,
      current_monthly_price: subscription&.ai_service_plan&.monthly_price,
      target_monthly_price: plan.monthly_price,
      amount_due: amount_due(subscription),
      currency: plan.currency,
      requested_ai_replies: purpose == 'top_up' ? plan.top_up_ai_replies : nil,
      resulting_included_ai_replies: plan.included_ai_replies,
      renews_at: subscription&.renews_at,
      reporting_timezone: subscription&.reporting_timezone,
      unit_price_comparison: unit_price_comparison(subscription)
    )
  end

  def purchase_balance(subscription)
    AiLeadEmployee::Subscriptions::PurchaseBalance.new(
      subscription: subscription, plan: plan, purpose: purpose
    ).to_h
  end

  def amount_due(subscription)
    return plan.top_up_price if purpose == 'top_up'
    return plan.monthly_price unless purpose == 'upgrade'

    plan.monthly_price - subscription.ai_service_plan.monthly_price
  end

  def unit_price_comparison(subscription)
    source_plan, comparison_plan = comparison_plans(subscription)
    return unless source_plan&.top_up_price && source_plan.top_up_ai_replies && comparison_plan

    top_up_unit_price = source_plan.top_up_price / source_plan.top_up_ai_replies
    included_unit_price = comparison_plan.monthly_price / comparison_plan.included_ai_replies
    return unless top_up_unit_price > included_unit_price

    {
      comparison_plan_name: comparison_plan.name,
      top_up_unit_price: top_up_unit_price,
      included_unit_price: included_unit_price,
      savings_percentage: (((top_up_unit_price - included_unit_price) / top_up_unit_price) * 100).round(1).to_f
    }
  end

  def comparison_plans(subscription)
    return [subscription.ai_service_plan, plan] if purpose == 'upgrade'
    return unless purpose == 'top_up'

    comparison = AiLeadEmployee::AiServicePlan.published
                                              .where(currency: plan.currency)
                                              .where('included_ai_replies > ?', plan.included_ai_replies)
                                              .where('monthly_price > ?', plan.monthly_price)
                                              .order(:included_ai_replies, :monthly_price, :id)
                                              .first
    [plan, comparison]
  end
end
