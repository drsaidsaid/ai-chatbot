# frozen_string_literal: true

class AiLeadEmployee::OperationalDashboardRow
  def initialize(qualification:, conversation:, open_reviews:)
    @qualification = qualification
    @conversation = conversation
    @open_reviews = open_reviews
  end

  def to_h
    contact_payload
      .merge(qualification_payload)
      .merge(conversation_payload)
      .merge(rebuild_payload)
      .merge(booking_state: booking_state)
  end

  private

  attr_reader :qualification, :conversation, :open_reviews

  def contact
    qualification.contact
  end

  def contact_payload
    {
      id: contact.id,
      name: contact.name,
      email: contact.email,
      phone_number: contact.phone_number,
      contact_details: contact_details
    }
  end

  def qualification_payload
    {
      quality: qualification.quality,
      follow_up_state: qualification.follow_up_state,
      score: qualification.score,
      reasons: qualification.reasons,
      missing_signals: qualification.missing_signals
    }
  end

  def conversation_payload
    conversation_identity_payload
      .merge(conversation_state_payload)
      .merge(conversation_activity_payload)
  end

  def conversation_identity_payload
    {
      assignee: user_payload(conversation&.assignee),
      source: source_payload(conversation&.inbox),
      conversation_id: conversation&.id,
      conversation_display_id: conversation&.display_id
    }
  end

  def conversation_state_payload
    {
      control_state: conversation&.control_state,
      conversation_status: conversation&.status,
      unanswered_questions_count: open_reviews.count,
      unread_count: unread_count
    }
  end

  def conversation_activity_payload
    {
      last_message_preview: last_message_preview,
      last_activity_at: conversation&.last_activity_at,
      location: location
    }
  end

  def rebuild_payload
    {
      authoritative_labels: authoritative_labels,
      authoritative_custom_attributes: authoritative_custom_attributes
    }
  end

  def contact_details
    {
      email: contact.email,
      phone_number: contact.phone_number,
      additional_attributes: contact.additional_attributes || {}
    }
  end

  def user_payload(assignee)
    return if assignee.blank?

    { id: assignee.id, name: assignee.name, email: assignee.email }
  end

  def source_payload(inbox)
    return if inbox.blank?

    { id: inbox.id, name: inbox.name, channel_type: inbox.channel_type }
  end

  def booking_state
    qualification.call_booked? ? 'booked' : 'not_booked'
  end

  def last_message_preview
    return nil if conversation.blank?

    conversation.messages.non_activity_messages.last&.content
  end

  def unread_count
    return 0 if conversation.blank?

    conversation.unread_incoming_messages.count
  end

  def location
    [contact_attributes['city'], contact_attributes['country']]
      .compact_blank
      .join(', ')
      .presence || contact_attributes['location']
  end

  def contact_attributes
    @contact_attributes ||= contact.additional_attributes || {}
  end

  def authoritative_labels
    [
      "ai-quality-#{qualification.quality.tr('_', '-')}",
      "ai-follow-up-#{qualification.follow_up_state.tr('_', '-')}",
      ("ai-#{booking_state.tr('_', '-')}" if booking_state == 'booked')
    ].compact
  end

  def authoritative_custom_attributes
    {
      lead_quality: qualification.quality,
      follow_up_state: qualification.follow_up_state,
      booking_state: booking_state,
      qualification_score: qualification.score
    }
  end
end
