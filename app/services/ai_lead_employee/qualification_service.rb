# frozen_string_literal: true

class AiLeadEmployee::QualificationService
  # Retained for reading pre-Offer decisions and building explicit Offer
  # configurations. They are never applied without a configured Offer.
  REQUIRED_HIGHLY_QUALIFIED_SIGNALS = %w[problem budget urgency decision_authority].freeze
  SIGNAL_WEIGHTS = {
    'name' => 0,
    'business_type' => 10,
    'problem' => 20,
    'lead_volume' => 10,
    'urgency' => 20,
    'budget' => 20,
    'decision_authority' => 20,
    'contact_details' => 10
  }.freeze

  Result = Struct.new(:qualification, :qualification_context, :next_question, :next_question_key, :new_evidence, :review_request_reason,
                      :qualification_mode, :offer_id, :assessment, :next_step,
                      keyword_init: true)

  def initialize(conversation:, incoming_message: nil)
    @conversation = conversation
    @incoming_message = incoming_message
    @account = conversation.account
  end

  def perform
    return unconfigured_result unless conversation.offer_id.present? || account.qualification_offers.exists?

    AiLeadEmployee::OfferQualificationService.new(conversation: conversation, incoming_message: incoming_message).perform
  end

  private

  attr_reader :account, :conversation, :incoming_message

  def unconfigured_result
    Result.new(
      qualification: nil,
      next_question: nil,
      next_question_key: nil,
      new_evidence: [],
      qualification_mode: 'not_configured'
    )
  end
end
