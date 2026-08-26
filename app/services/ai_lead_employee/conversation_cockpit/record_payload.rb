# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpit::RecordPayload
  class << self
    def booking(booking)
      return nil if booking.blank?

      {
        id: booking.id,
        status: booking.status,
        starts_at: booking.starts_at.iso8601,
        ends_at: booking.ends_at.iso8601,
        timezone: booking.timezone,
        provider: booking.provider,
        calendar_id: booking.calendar_id,
        assignee: user_payload(booking.assignee),
        calendar_invitation_sent_at: booking.calendar_invitation_sent_at&.iso8601,
        confirmation_message_id: booking.confirmation_message_id
      }
    end

    def handoff(handoff)
      return nil if handoff.blank?

      {
        id: handoff.id,
        status: handoff.status,
        alert_type: handoff.alert_type,
        handed_off_at: handoff.handed_off_at.iso8601,
        assignee: user_payload(handoff.assignee),
        alert_recipients: handoff.alert_recipients
      }
    end

    def review(review)
      {
        id: review.id,
        question: review.question,
        reason: review.reason,
        status: review.status,
        created_at: review.created_at.iso8601,
        resolved_at: review.resolved_at&.iso8601
      }
    end

    private

    def user_payload(user)
      return nil if user.blank?

      { id: user.id, name: user.name, email: user.email }
    end
  end
end
