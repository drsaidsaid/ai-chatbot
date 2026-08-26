# frozen_string_literal: true

class AiLeadEmployee::ConversationCockpit::Context
  EMPTY_VALUE = 'Not captured'

  attr_reader :conversation

  delegate :account, :contact, to: :conversation

  def initialize(conversation:)
    @conversation = conversation
  end

  def qualification
    @qualification ||= contact&.lead_qualification
  end

  def evidence_snapshot
    qualification&.evidence_snapshot || {}
  end

  def open_reviews
    @open_reviews ||= conversation.human_review_requests.open.order(created_at: :asc)
  end

  def latest_booking
    return @latest_booking if defined?(@latest_booking)

    @latest_booking =
      conversation.bookings.active.order(starts_at: :asc).first ||
      conversation.bookings.order(starts_at: :desc).first
  end

  def latest_handoff
    @latest_handoff ||= conversation.lead_handoffs.order(handed_off_at: :desc).first
  end

  def source_payload
    {
      channel: conversation.inbox&.channel_type,
      inbox_name: conversation.inbox&.name,
      direction: 'Inbound',
      first_message_at: first_incoming_message_at,
      phone_number: contact&.phone_number
    }
  end

  def key_value(label, value)
    { label: label, value: value.presence || EMPTY_VALUE }
  end

  def evidence_label(signal)
    value = evidence_snapshot[signal.to_s] || evidence_snapshot[signal.to_sym]
    stringify_evidence_value(value)
  end

  def stringify_evidence_value(value)
    return stringify_hash_value(value) if value.is_a?(Hash)
    return stringify_array_value(value) if value.is_a?(Array)

    value.to_s.presence
  end

  def buying_intent
    return EMPTY_VALUE if qualification.blank?
    return 'High' if high_buying_intent?
    return 'Medium' if medium_buying_intent?
    return 'Low' if low_buying_intent?

    'Unknown'
  end

  def potential_value
    [
      evidence_label(:budget),
      evidence_label(:team_size),
      evidence_label(:company_size)
    ].compact.join(' - ').presence || EMPTY_VALUE
  end

  def confidence_label
    return EMPTY_VALUE if qualification.blank?
    return 'High' if qualification.score.to_i >= 75
    return 'Medium' if qualification.score.to_i >= 45

    'Low'
  end

  def booking_time_label(booking)
    return EMPTY_VALUE if booking.blank?

    "#{booking.starts_at.strftime('%b %-d, %Y at %-I:%M %p')} #{booking.timezone}"
  end

  def user_payload(user)
    return nil if user.blank?

    { id: user.id, name: user.name, email: user.email }
  end

  def humanize(value)
    value.to_s.tr('.', '_').tr('-', '_').split('_').map(&:capitalize).join(' ')
  end

  private

  def first_incoming_message_at
    conversation.messages.incoming.order(created_at: :asc).first&.created_at&.iso8601
  end

  def stringify_hash_value(value)
    stringify_evidence_value(
      value['value'] || value[:value] || value['label'] || value[:label]
    )
  end

  def stringify_array_value(value)
    value.map { |entry| stringify_evidence_value(entry) }.reject(&:blank?).join(', ')
  end

  def high_buying_intent?
    qualification.highly_qualified? || qualification.score.to_i >= 80
  end

  def medium_buying_intent?
    qualification.qualified? || qualification.score.to_i >= 50
  end

  def low_buying_intent?
    qualification.low_qualified? || qualification.unqualified?
  end
end
