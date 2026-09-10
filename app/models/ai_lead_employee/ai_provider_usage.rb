# frozen_string_literal: true

class AiLeadEmployee::AiProviderUsage < ApplicationRecord
  self.table_name = 'ai_provider_usages'

  STATUSES = %w[reserved completed failed].freeze
  PURPOSES = %w[answer health_check evaluation].freeze

  belongs_to :account
  belongs_to :ai_provider_connection, class_name: 'AiLeadEmployee::AiProviderConnection'

  enum :status, STATUSES.index_with(&:itself)

  validates :configuration_version, :requested_output_tokens, numericality: { only_integer: true, greater_than: 0 }
  validates :purpose, inclusion: { in: PURPOSES }
  validates :status, inclusion: { in: STATUSES }
  validates :period_on, :started_at, presence: true

  scope :for_utc_day, ->(day) { where(period_on: day) }
end
