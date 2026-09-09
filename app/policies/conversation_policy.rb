class ConversationPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      conversations = scope.where(account: account)
      return conversations if account_user&.administrator?
      return conversations.none unless user.is_a?(User)

      inbox_ids = user.inboxes.where(account: account).select(:id)
      team_ids = user.teams.where(account: account).select(:id)
      conversations.where(inbox_id: inbox_ids).or(conversations.where(team_id: team_ids))
    end
  end

  def index?
    true
  end

  def destroy?
    administrator?
  end

  def show?
    administrator? || agent_bot? || agent_can_view_conversation?
  end

  def control?
    user.is_a?(User) && (administrator? || agent_can_view_conversation?)
  end

  private

  def agent_can_view_conversation?
    inbox_access? || team_access?
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end

  def inbox_access?
    user.inboxes.where(account_id: account&.id).exists?(id: record.inbox_id)
  end

  def team_access?
    return false if record.team_id.blank?

    user.teams.where(account_id: account&.id).exists?(id: record.team_id)
  end

  def assigned_to_user?
    record.assignee_id == user.id
  end

  def participant?
    record.conversation_participants.exists?(user_id: user.id)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
