# frozen_string_literal: true

class AiLeadEmployee::SubscriptionAlertDeliveryJob < ApplicationJob
  queue_as :default

  def perform(alert)
    AiLeadEmployee::SubscriptionAlertDeliveryService.new(alert: alert).perform
  end
end
