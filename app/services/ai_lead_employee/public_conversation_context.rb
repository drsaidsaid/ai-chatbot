# frozen_string_literal: true

class AiLeadEmployee::PublicConversationContext
  LIMIT = 6
  CONTENT_LIMIT = 400

  def initialize(conversation:, through_message:)
    @conversation = conversation
    @through_message = through_message
  end

  def to_a
    public_messages.to_a.reverse.map do |message|
      {
        role: message.incoming? ? 'lead' : 'business',
        content: message.content.to_s.squish.truncate(CONTENT_LIMIT)
      }
    end
  end

  private

  attr_reader :conversation, :through_message

  def public_messages
    conversation.messages.where(private: false).where('id <= ?', through_message.id).reorder(id: :desc).limit(LIMIT)
  end
end
