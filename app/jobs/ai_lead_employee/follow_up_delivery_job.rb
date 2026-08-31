# frozen_string_literal: true

class AiLeadEmployee::FollowUpDeliveryJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(follow_up = nil)
    return deliver(follow_up) if follow_up.present?

    LeadFollowUp.pending.where(scheduled_at: ..Time.current).find_each { |due_follow_up| deliver(due_follow_up) }
  end

  private

  def deliver(follow_up)
    AiLeadEmployee::FollowUpDeliveryService.new(follow_up: follow_up).perform
  end
end
