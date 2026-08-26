# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpitPresenter
  def initialize(conversation:)
    @context = AiLeadEmployee::ConversationCockpit::Context.new(conversation: conversation)
  end

  def to_h
    {
      summary: summary_payload,
      evidence: evidence_payload,
      activity: activity_payload,
      booking: record_payload.booking(context.latest_booking),
      handoff: record_payload.handoff(context.latest_handoff),
      open_reviews: context.open_reviews.map { |review| record_payload.review(review) },
      next_action: next_action_payload
    }
  end

  private

  attr_reader :context

  def summary_payload
    AiLeadEmployee::ConversationCockpit::SummaryPayload.new(
      context,
      evidence_rows: evidence_payload
    ).to_h
  end

  def evidence_payload
    @evidence_payload ||= AiLeadEmployee::ConversationCockpit::EvidencePayload.new(context).to_a
  end

  def activity_payload
    AiLeadEmployee::ConversationCockpit::ActivityPayload.new(context).to_a
  end

  def next_action_payload
    @next_action_payload ||= AiLeadEmployee::ConversationCockpit::NextActionPayload.new(context).to_h
  end

  def record_payload
    AiLeadEmployee::ConversationCockpit::RecordPayload
  end
end
