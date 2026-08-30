# frozen_string_literal: true

class AiLeadEmployee::OrchestrationIntentJob < ApplicationJob
  queue_as :low

  retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout, wait: 2.seconds, attempts: 5

  def perform(intent_id)
    intent = AiLeadEmployee::OrchestrationIntent.find(intent_id)
    AiLeadEmployee::Orchestration::IntentProcessor.new(intent: intent).perform
  end
end
