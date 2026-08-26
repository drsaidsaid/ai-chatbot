# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpit::SummaryPayload
  STRONG_EVIDENCE_LIMIT = 3

  def initialize(context, evidence_rows: nil)
    @context = context
    @evidence_rows = evidence_rows
  end

  def to_h
    {
      why: summary_rows,
      strongest_evidence: strongest_evidence,
      missing_signals: Array(context.qualification&.missing_signals),
      source: context.source_payload,
      next_recommended_action: next_action_payload
    }
  end

  private

  attr_reader :context

  def summary_rows
    [
      role_fit_row,
      goal_row,
      context.key_value('Buying intent', context.buying_intent),
      context.key_value('Potential value', context.potential_value),
      context.key_value('Confidence', context.confidence_label)
    ]
  end

  def role_fit_row
    context.key_value(
      'Role fit',
      context.evidence_label(:role) || context.evidence_label(:business_type)
    )
  end

  def goal_row
    context.key_value(
      'Goal',
      context.evidence_label(:problem) || context.qualification&.reasons&.first
    )
  end

  def strongest_evidence
    reasons = Array(context.qualification&.reasons).filter_map(&:presence)
    return reasons.first(STRONG_EVIDENCE_LIMIT) if reasons.present?

    evidence_rows.filter_map { |item| evidence_summary(item) }.first(STRONG_EVIDENCE_LIMIT)
  end

  def evidence_rows
    @evidence_rows ||= AiLeadEmployee::ConversationCockpit::EvidencePayload.new(context).to_a
  end

  def evidence_summary(item)
    return if item[:value].blank?

    "#{context.humanize(item[:signal])}: #{item[:value]}"
  end

  def next_action_payload
    AiLeadEmployee::ConversationCockpit::NextActionPayload.new(context).to_h
  end
end
