# frozen_string_literal: true

class AiLeadEmployee::Orchestration::ProviderFailureHandler
  def initialize(intent:, failure:, enqueue_review_alerts: true)
    @intent = intent
    @failure = failure
    @enqueue_review_alerts = enqueue_review_alerts
  end

  def perform
    intent.reload if intent.persisted?
    intent.with_lock do
      next intent if intent.terminal?

      intent.update!(blocked_attributes)
    end
    intent
  end

  private

  attr_reader :intent, :failure, :enqueue_review_alerts

  def block_reasons
    AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS
  end

  def blocked_attributes
    {
      state: :blocked,
      blocked_reason: block_reasons[:provider_failure],
      failure_class: failure.failure_class,
      review_request: review_result.request,
      decision: {
        status: 'provider_failed',
        failure_class: failure.failure_class
      },
      blocked_at: Time.current
    }
  end

  def review_result
    @review_result ||= AiLeadEmployee::HumanReviewRequestService.new(
      conversation: intent.conversation,
      lead_message: intent.triggering_message,
      reason: 'provider_failed',
      enqueue_alerts: enqueue_review_alerts
    ).perform
  end
end
