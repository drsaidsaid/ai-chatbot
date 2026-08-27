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

  def reschedule?
    index?
  end

  def cancel?
    index?
  end

  class Scope < Scope
    def resolve
      return scope.none if account_user.blank?

      scope.where(account_id: account.id)
    end
  end
end
