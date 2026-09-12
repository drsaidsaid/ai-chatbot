# frozen_string_literal: true

class Whatsapp::SubscriptionAlertRecipientResolver
  def self.for(account)
    account.administrators.filter_map do |administrator|
      phone = administrator.custom_attributes&.dig('whatsapp_alert_phone').presence
      Whatsapp::RecipientIdentifier.normalize(phone) if phone
    end.uniq
  end
end
