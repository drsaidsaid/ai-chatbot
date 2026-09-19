# frozen_string_literal: true

class AiLeadEmployee::Offer < ApplicationRecord
  QUALIFICATION_MODES = %w[not_configured disabled enabled].freeze
  NEXT_STEP_KINDS = %w[answer_only enquiry purchase_link sales_call appointment].freeze
  self.table_name = 'ai_lead_employee_offers'

  belongs_to :account
  has_many :configuration_revisions, class_name: 'AiLeadEmployee::OfferConfigurationRevision', dependent: :restrict_with_exception
  has_many :lead_qualifications, dependent: :restrict_with_exception
  has_one :commercial_term, class_name: 'AiLeadEmployee::OfferCommercialTerm', dependent: :restrict_with_exception
  has_many :commercial_proposals, class_name: 'AiLeadEmployee::OfferCommercialProposal', dependent: :restrict_with_exception
  has_many :business_setup_sources, class_name: 'AiLeadEmployee::BusinessSetupSource', dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :currency, inclusion: { in: AiLeadEmployee::OfferMoney::PRECISION.keys }
  validates :configuration_version, numericality: { only_integer: true, greater_than: 0 }

  scope :enabled_in_order, -> { where(enabled: true).order(:position, :id) }

  def questions
    configuration.fetch('questions', []).select { |question| question['enabled'] }.sort_by { |question| question['position'] }
  end

  def budget_ranges
    configuration.fetch('budget_ranges', []).select { |range| range['enabled'] }
  end

  def qualification_mode
    configured = configuration['qualification_mode']
    return configured if QUALIFICATION_MODES.include?(configured)

    qualification_configured? ? 'enabled' : 'not_configured'
  end

  def qualification_enabled?
    qualification_mode == 'enabled'
  end

  def next_step
    configuration.fetch('next_step', { 'kind' => 'answer_only' })
  end

  def payload
    configuration.merge('id' => id, 'name' => name, 'currency' => currency, 'enabled' => enabled,
                        'version' => configuration_version, 'budget_ranges' => public_budget_ranges,
                        'commercial_terms_draft' => commercial_term&.draft_payload,
                        'published_commercial_terms' => commercial_term&.published_payload,
                        'commercial_proposals' => commercial_proposals.order(created_at: :desc).map(&:payload))
  end

  private

  def qualification_configured?
    configuration.fetch('questions', []).any? || configuration.fetch('rules', []).any? ||
      configuration.fetch('score_weights', {}).any?
  end

  def public_budget_ranges
    configuration.fetch('budget_ranges', []).map do |range|
      range.except('minimum_minor', 'maximum_minor').merge(
        'minimum' => AiLeadEmployee::OfferMoney.format(range['minimum_minor'], currency),
        'maximum' => AiLeadEmployee::OfferMoney.format(range['maximum_minor'], currency)
      )
    end
  end
end
