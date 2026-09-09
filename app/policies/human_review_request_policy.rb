# frozen_string_literal: true

class HumanReviewRequestPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def show?
    AiLeadEmployee::AccessScope.new(account: account, user: user).related(HumanReviewRequest).exists?(id: record.id)
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
