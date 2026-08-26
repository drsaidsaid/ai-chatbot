# frozen_string_literal: true

class AiLeadEmployee::FollowUpDeliveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(follow_up)
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform
  end
end
