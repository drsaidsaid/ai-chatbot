class ConversationPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      AiLeadEmployee::AccessScope.new(account: account, user: user).conversations(scope)
    end
  end

  def index?
    true
  end

  def destroy?
    administrator?
  end

  def show?
    return false unless record.account_id == account&.id

    agent_bot? || access.conversations.exists?(id: record.id)
  end

  def control?
    user.is_a?(User) && show?
  end

  private

  def administrator?
    access.administrator? && record.account_id == account&.id
  end

  def access
    AiLeadEmployee::AccessScope.new(account: account, user: user)
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end
end

ConversationPolicy.prepend_mod_with('ConversationPolicy')
