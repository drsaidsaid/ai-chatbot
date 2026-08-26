# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpit::ActivityPayload
  ACTIVITY_LIMIT = 24

  def initialize(context)
    @context = context
  end

  def to_a
    activity_collections
      .flatten
      .compact
      .sort_by { |item| item[:occurred_at].to_s }
      .last(ACTIVITY_LIMIT)
  end

  private

  attr_reader :context

  def activity_collections
    [
      audit_activities,
      review_activities,
      booking_activities,
      handoff_activities,
      follow_up_activities,
      whatsapp_activities,
      ai_decision_activities
    ]
  end

  def audit_activities
    Audited::Audit.where(auditable: context.conversation).order(created_at: :asc).filter_map do |audit|
      audit_activity(audit)
    end
  end

  def audit_activity(audit)
    changes = audit.audited_changes || {}
    return control_activity(audit, changes) if changes['ai_lead_employee_action'].present?
    return assignment_activity(audit) if changes.key?('assignee_id')

    nil
  end

  def control_activity(audit, changes)
    activity_item(
      id: "audit-#{audit.id}",
      kind: 'control',
      label: context.humanize(changes['ai_lead_employee_action']),
      detail: control_change_detail(changes),
      occurred_at: audit.created_at,
      tone: 'blue'
    )
  end

  def assignment_activity(audit)
    activity_item(
      id: "audit-#{audit.id}",
      kind: 'assignment',
      label: 'Assignment changed',
      detail: 'Human Operator ownership updated',
      occurred_at: audit.created_at,
      tone: 'slate'
    )
  end

  def control_change_detail(changes)
    states = changes['control_state']
    return 'Control State updated' unless states.is_a?(Array) && states.length == 2

    "#{context.humanize(states.first)} to #{context.humanize(states.last)}"
  end

  def review_activities
    context.conversation.human_review_requests.order(created_at: :asc).flat_map do |review|
      [review_open_activity(review), review_resolved_activity(review)].compact
    end
  end

  def review_open_activity(review)
    activity_item(
      id: "review-open-#{review.id}",
      kind: 'review',
      label: 'Review requested',
      detail: review.question,
      occurred_at: review.created_at,
      tone: 'amber'
    )
  end

  def review_resolved_activity(review)
    return if review.resolved_at.blank?

    activity_item(
      id: "review-resolved-#{review.id}",
      kind: 'review',
      label: 'Review resolved',
      detail: context.humanize(review.reason),
      occurred_at: review.resolved_at,
      tone: 'teal'
    )
  end

  def booking_activities
    context.conversation.bookings.order(starts_at: :asc).map do |booking|
      activity_item(
        id: "booking-#{booking.id}",
        kind: 'booking',
        label: "Booking #{context.humanize(booking.status)}",
        detail: context.booking_time_label(booking),
        occurred_at: booking.created_at,
        tone: 'teal'
      )
    end
  end

  def handoff_activities
    context.conversation.lead_handoffs.order(handed_off_at: :asc).map do |handoff|
      activity_item(
        id: "handoff-#{handoff.id}",
        kind: 'handoff',
        label: 'Handoff created',
        detail: handoff.assignee&.name || context.humanize(handoff.alert_type),
        occurred_at: handoff.handed_off_at,
        tone: 'blue'
      )
    end
  end

  def follow_up_activities
    context.qualification&.lead_follow_ups&.order(created_at: :asc)&.map do |follow_up|
      activity_item(
        id: "follow-up-#{follow_up.id}",
        kind: 'follow_up',
        label: "Follow-up #{context.humanize(follow_up.status)}",
        detail: follow_up.question_text,
        occurred_at: follow_up_occurred_at(follow_up),
        tone: 'slate'
      )
    end || []
  end

  def follow_up_occurred_at(follow_up)
    [
      follow_up.sent_at,
      follow_up.cancelled_at,
      follow_up.failed_at,
      follow_up.scheduled_at,
      follow_up.created_at
    ].find(&:present?)
  end

  def whatsapp_activities
    context.conversation.meta_whatsapp_webhook_events.order(created_at: :asc).limit(10).map do |event|
      activity_item(
        id: "whatsapp-#{event.id}",
        kind: 'delivery',
        label: context.humanize(event.event_kind),
        detail: event.provider_event_id,
        occurred_at: event.processed_at || event.created_at,
        tone: 'slate'
      )
    end
  end

  def ai_decision_activities
    decision = context.conversation.additional_attributes&.dig('ai_employee_last_decision')
    return [] if decision.blank?

    [
      activity_item(
        id: 'ai-last-decision',
        kind: 'ai_decision',
        label: 'AI decision recorded',
        detail: decision_summary(decision),
        occurred_at: context.conversation.updated_at,
        tone: 'blue'
      )
    ]
  end

  def decision_summary(decision)
    return "Review needed: #{context.humanize(decision['refusal_reason'])}" if decision['refusal_reason'].present?
    return "Used #{decision['sources'].length} approved source" if decision['sources'].present?

    'Conversation evaluated'
  end

  def activity_item(attributes)
    {
      id: attributes.fetch(:id),
      kind: attributes.fetch(:kind),
      label: attributes.fetch(:label),
      detail: attributes[:detail].to_s.presence || AiLeadEmployee::ConversationCockpit::Context::EMPTY_VALUE,
      occurred_at: attributes[:occurred_at]&.iso8601,
      tone: attributes.fetch(:tone)
    }
  end
end
