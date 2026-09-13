# frozen_string_literal: true

class AiLeadEmployee::Subscriptions::RequestService
  InvalidRequest = Class.new(StandardError)
  FutureCyclePrepaid = Class.new(InvalidRequest)

  def initialize(account:, requested_by:, plan:, purpose:, preview_signature: nil)
    @account = account
    @requested_by = requested_by
    @plan = plan
    @purpose = purpose.to_s
    @preview_signature = preview_signature
  end

  def perform
    request_record = nil
    purchase_preview.perform do |preview, subscription|
      validate_preview_signature!(preview)
      request_record = AiLeadEmployee::AiSubscriptionRequest.create!(
        account: account,
        ai_service_plan: plan,
        expected_current_plan: subscription&.ai_service_plan,
        expected_subscription_updated_at: subscription&.updated_at,
        requested_by: requested_by,
        purpose: purpose,
        quoted_amount: preview.fetch(:amount_due),
        currency: preview.fetch(:currency),
        requested_ai_replies: preview[:requested_ai_replies],
        payment_instructions: plan.payment_instructions
      )
    end
    request_record
  rescue AiLeadEmployee::Subscriptions::PurchasePreview::InvalidPreview => e
    raise request_error_for(e), e.message
  end

  private

  attr_reader :account, :requested_by, :plan, :purpose, :preview_signature

  def request_error_for(error)
    return FutureCyclePrepaid if error.is_a?(AiLeadEmployee::Subscriptions::PurchasePreview::FutureCyclePrepaid)

    InvalidRequest
  end

  def validate_preview_signature!(preview)
    return unless purpose.in?(%w[top_up upgrade])
    return if preview_signature.present? && AiLeadEmployee::Subscriptions::PurchasePreview.signature_valid?(
      preview_signature, account: account, preview: preview
    )

    raise InvalidRequest, 'Your balance changed or the preview expired. Review the purchase again.'
  end

  def purchase_preview
    AiLeadEmployee::Subscriptions::PurchasePreview.new(
      account: account, plan: plan, purpose: purpose
    )
  end
end
