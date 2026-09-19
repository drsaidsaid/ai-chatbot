# frozen_string_literal: true

class LeadHandoffPolicy < ApplicationPolicy
  def show?
    AiLeadEmployee::AccessScope.new(account: account, user: user).related(LeadHandoff).exists?(id: record.id)
  end

  def update?
    show?
  end

  class Scope < Scope
    def resolve
      AiLeadEmployee::AccessScope.new(account: account, user: user).related(scope)
    end
  end
end
