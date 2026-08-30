# frozen_string_literal: true

class LeadQualificationPolicy < ApplicationPolicy
  def show?
    same_business_account?
  end

  def evidence?
    same_business_account?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if account_user.blank?

      scope.where(account_id: account.id)
    end
  end

  private

  def same_business_account?
    account_user.present? && record.account_id == account.id
  end
end
