# frozen_string_literal: true

# Persists Meta webhook events before domain processing so retries are harmless.
# == Schema Information
#
# Table name: meta_whatsapp_webhook_events
#
#  id                  :bigint           not null, primary key
#  event_kind          :string           not null
#  payload             :jsonb            not null
#  processed_at        :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  channel_whatsapp_id :bigint           not null
#  conversation_id     :bigint
#  inbox_id            :bigint           not null
#  provider_event_id   :string           not null
#
# Indexes
#
#  index_meta_whatsapp_webhook_events_on_account_id           (account_id)
#  index_meta_whatsapp_webhook_events_on_channel_whatsapp_id  (channel_whatsapp_id)
#  index_meta_whatsapp_webhook_events_on_conversation_id      (conversation_id)
#  index_meta_whatsapp_webhook_events_on_inbox_id             (inbox_id)
#  index_meta_whatsapp_webhook_events_on_provider_event_id    (provider_event_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (channel_whatsapp_id => channel_whatsapp.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#
class MetaWhatsappWebhookEvent < ApplicationRecord
  belongs_to :account
  belongs_to :inbox
  belongs_to :channel_whatsapp, class_name: 'Channel::Whatsapp'
  belongs_to :conversation, optional: true

  validates :provider_event_id, presence: true
  validates :event_kind, presence: true
  validates :payload, presence: true
end
