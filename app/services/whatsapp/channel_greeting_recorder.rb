class Whatsapp::ChannelGreetingRecorder
  def initialize(message)
    @message = message
  end

  def perform
    return unless @message.incoming?

    conversation = @message.conversation
    conversation.reload.with_lock do
      inbox = conversation.inbox
      return unless inbox.greeting_enabled? && inbox.greeting_message.present? && conversation.campaign.blank?
      return if conversation.messages.exists?(message_type: [:outgoing, :template])

      conversation.messages.create!(account: conversation.account, inbox: inbox, message_type: :template, content: inbox.greeting_message,
                                    additional_attributes: { ai_lead_employee: { delivery_type: 'channel_greeting',
                                                                                 triggering_message_id: @message.id } })
    end
  end
end
