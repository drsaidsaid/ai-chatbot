# frozen_string_literal: true

# == Schema Information
#
# Table name: ai_provider_connections
#
#  id                        :bigint           not null, primary key
#  api_key                   :text
#  disabled_at               :datetime
#  last_health_checked_at    :datetime
#  last_health_failure_class :string
#  last_health_response      :jsonb            not null
#  last_health_status        :string
#  model                     :string           not null
#  provider                  :string           default("openrouter"), not null
#  status                    :integer          default("active"), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#
# Indexes
#
#  index_ai_provider_connections_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AiLeadEmployee::AiProviderConnection < ApplicationRecord
  self.table_name = 'ai_provider_connections'

  PROVIDERS = %w[openrouter].freeze

  belongs_to :account

  encrypts :api_key if Chatwoot.encryption_configured?

  enum :status, { active: 0, disabled: 1 }

  validates :provider, inclusion: { in: PROVIDERS }
  validates :model, presence: true
  validates :api_key, presence: true, if: :active?
  validate :api_key_requires_configured_encryption

  def disable!
    update!(api_key: nil, status: :disabled, disabled_at: Time.current)
  end

  def configured?
    active? && api_key.present?
  end

  def redacted_payload
    {
      id: id,
      provider: provider,
      model: model,
      status: status,
      has_credentials: api_key.present?,
      disabled_at: disabled_at,
      last_health_checked_at: last_health_checked_at,
      last_health_status: last_health_status,
      last_health_failure_class: last_health_failure_class
    }
  end

  private

  def api_key_requires_configured_encryption
    return if api_key.blank? || Chatwoot.encryption_configured?

    errors.add(:api_key, 'cannot be stored until Active Record encryption is configured')
  end
end
