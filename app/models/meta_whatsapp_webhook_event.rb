# frozen_string_literal: true

# Persists Meta webhook events before domain processing so retries are harmless.
class MetaWhatsappWebhookEvent < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :channel_whatsapp, class_name: 'Channel::Whatsapp'

  validates :provider_event_id, presence: true
  validates :event_kind, presence: true
  validates :payload, presence: true
end
