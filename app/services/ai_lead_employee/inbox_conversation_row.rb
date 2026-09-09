class AiLeadEmployee::InboxConversationRow
  def initialize(conversation, last_message_preview:)
    @conversation = conversation
    @last_message_preview = last_message_preview
  end

  def to_h
    identity.merge(qualification_payload).merge(activity)
  end

  private

  def identity
    {
      id: conversation.contact_id,
      conversation_id: conversation.id,
      conversation_display_id: conversation.display_id,
      name: contact.name,
      phone_number: contact.phone_number,
      control_state: conversation.control_state,
      assignee: conversation.assignee&.slice(:id, :name),
      source: conversation.inbox.slice(:id, :name, :channel_type),
      unanswered_questions_count: conversation.human_review_requests.count(&:open?)
    }
  end

  def qualification_payload
    return { quality: 'unknown', follow_up_state: 'no_follow_up', score: nil, reasons: [] } unless qualification

    qualification.slice(:quality, :follow_up_state, :score, :reasons).symbolize_keys
  end

  def activity
    {
      last_activity_at: conversation.last_activity_at,
      last_message_preview: last_message_preview
    }
  end

  attr_reader :conversation, :last_message_preview

  def contact
    conversation.contact
  end

  def qualification
    contact.lead_qualification
  end
end
