# frozen_string_literal: true

class AiLeadEmployee::BookingPrerequisiteChecker
  Result = Data.define(:met, :failure_code, :snapshot) do
    def met? = met
  end

  def initialize(conversation:, offer:)
    @conversation = conversation
    @offer = offer
  end

  def perform
    kind = offer.next_step['prerequisite'].presence
    return Result.new(met: true, failure_code: nil, snapshot: { 'kind' => 'none', 'status' => 'met' }) if kind.blank?

    # R28 supplies the verified payment adapter. R13 deliberately fails closed
    # until that adapter returns an account/Offer-scoped confirmation.
    Result.new(
      met: false,
      failure_code: "#{kind}_required",
      snapshot: { 'kind' => kind, 'status' => 'required', 'offer_id' => offer.id, 'conversation_id' => conversation.id }
    )
  end

  private

  attr_reader :conversation, :offer
end
