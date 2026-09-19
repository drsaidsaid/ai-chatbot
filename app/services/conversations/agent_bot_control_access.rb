# frozen_string_literal: true

class Conversations::AgentBotControlAccess
  def self.allowed?(conversation:, agent_bot:)
    assigned = conversation.assignee_agent_bot_id == agent_bot.id
    accessible = AgentBot.accessible_to(conversation.account).exists?(id: agent_bot.id)
    active_inbox = AgentBotInbox.active.exists?(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      agent_bot_id: agent_bot.id
    )
    assigned && accessible && active_inbox
  end
end
