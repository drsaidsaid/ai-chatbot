# frozen_string_literal: true

class AiLeadEmployee::PromotionEligibility
  def initialize(conversation:, offer:)
    @conversation = conversation
    @offer = offer
  end

  def value
    return unless valid_scope? && field_key.present?

    QualificationEvidence.current.find_by(
      account: conversation.account,
      contact: conversation.contact,
      offer: offer,
      field_key: field_key,
      observed_at: AiLeadEmployee::QualificationEvidenceSnapshot.fresh_after(conversation.account)..
    )&.value&.dig('typed_value')
  end

  private

  attr_reader :conversation, :offer

  def valid_scope?
    offer.present? && offer.account_id == conversation.account_id
  end

  def field_key
    @field_key ||= offer&.commercial_term&.published_revision&.snapshot&.dig('promotion_eligibility_field')
  end
end
