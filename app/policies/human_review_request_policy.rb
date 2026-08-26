# frozen_string_literal: true

class HumanReviewRequestPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def show?
    account_user.present? && record.account_id == account.id
  end

  def update?
    show?
  end

  class Scope < Scope
    def resolve
      return scope.none if account_user.blank?

      scope.where(account_id: account.id)
    end
  end
end
