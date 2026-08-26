# frozen_string_literal: true

class LeadQualificationPolicy < ApplicationPolicy
  def show?
    true
  end

  def evidence?
    true
  end
end
