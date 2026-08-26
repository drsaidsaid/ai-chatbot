# frozen_string_literal: true

class AddConversationToMetaWhatsappWebhookEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :meta_whatsapp_webhook_events, :conversation, foreign_key: true
  end
end
