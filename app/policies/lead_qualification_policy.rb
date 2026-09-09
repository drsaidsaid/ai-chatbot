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
      AiLeadEmployee::AccessScope.new(account: account, user: user).qualifications(scope)
    end
  end

  private

  def same_business_account?
    record.account_id == account.id && AiLeadEmployee::AccessScope.new(account: account, user: user).contacts.exists?(id: record.contact_id)
  end
end
