# frozen_string_literal: true

class AiLeadEmployee::HandoffAlertRecipients
  def initialize(account:, alert_type:)
    @account = account
    @alert_type = alert_type
  end

  def for(assignee, fallback_routes: nil)
    routes = alert_routes
    routes = Array(fallback_routes) if routes.empty?
    routes.filter_map { |route| recipient_for(route, assignee) }.flatten.filter_map { |recipient| normalized_recipient(recipient) }.uniq
  end

  private

  attr_reader :account, :alert_type

  def alert_routes
    Array(account.reload.settings&.dig('ai_lead_employee', 'alert_routes', alert_type))
  end

  def recipient_for(route, assignee)
    case route.to_h['type']
    when 'assignee'
      whatsapp_alert_phone_for(assignee)
    when 'admin'
      account.administrators.map { |admin| whatsapp_alert_phone_for(admin) }
    when 'member'
      whatsapp_alert_phone_for(account.users.find_by(id: route.to_h['user_id']))
    when 'whatsapp'
      verified_alert_phone(route)
    end
  end

  def normalized_recipient(recipient)
    Whatsapp::RecipientIdentifier.normalize(recipient)
  end

  def whatsapp_alert_phone_for(user)
    return if user.blank?

    user.custom_attributes&.dig('whatsapp_alert_phone').presence
  end

  def verified_alert_phone(route)
    recipient = normalized_recipient(route.to_h['recipient'])
    account.users.reload.find do |user|
      normalized_recipient(user.custom_attributes&.dig('whatsapp_alert_phone')) == recipient
    end&.custom_attributes&.dig('whatsapp_alert_phone')
  end
end
