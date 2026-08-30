# frozen_string_literal: true

class AiLeadEmployee::Orchestration::ProviderFailureHandler
  def initialize(intent:, failure:)
    @intent = intent
    @failure = failure
  end

  def perform
    intent.reload if intent.persisted?
    intent.with_lock do
      next intent if intent.terminal?

      intent.update!(
        state: :blocked,
        blocked_reason: block_reasons[:provider_failure],
        failure_class: failure.failure_class,
        decision: {
          status: 'provider_failed',
          failure_class: failure.failure_class
        },
        blocked_at: Time.current
      )
    end
    intent
  end

  private

  attr_reader :intent, :failure

  def block_reasons
    AiLeadEmployee::Orchestration::DecisionPlaceholder::BLOCK_REASONS
  end
end
