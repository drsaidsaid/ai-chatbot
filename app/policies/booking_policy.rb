# frozen_string_literal: true

class BookingPolicy < ApplicationPolicy
  def index?
    account_user.present?
  end

  def create?
    account_user.present?
  end

  def available_slots?
    index?
  end

  def propose?
    create?
  end

  def reschedule?
    index?
  end

  def cancel?
    index?
  end

  def reconcile?
    index?
  end

  class Scope < Scope
    def resolve
      AiLeadEmployee::AccessScope.new(account: account, user: user).related(scope)
    end
  end
end
