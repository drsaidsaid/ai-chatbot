# frozen_string_literal: true

class AiLeadEmployee::QualificationBudgetClassifier
  DEFAULT_MINIMUM_CENTS = 10_000

  def self.out_of_range?(account:, budget_value:)
    new(account: account, budget_value: budget_value).out_of_range?
  end

  def initialize(account:, budget_value:)
    @account = account
    @budget_value = budget_value
  end

  def out_of_range?
    return false if budget_cents.blank?
    return budget_cents < DEFAULT_MINIMUM_CENTS if ranges.empty?

    ranges.none? { |range| includes_budget?(range) }
  end

  private

  attr_reader :account, :budget_value

  def budget_cents
    @budget_cents ||= begin
      normalized = budget_value.delete(',').downcase
      match = normalized.match(/(\d+)/)
      if match.present?
        amount = match[1].to_i
        amount *= 1000 if normalized.match?(/\bk\b|thousand/)
        amount * 100
      end
    end
  end

  def ranges
    @ranges ||= account.qualification_budget_ranges.enabled_in_order.to_a
  end

  def includes_budget?(range)
    (range.min_cents.blank? || budget_cents >= range.min_cents) &&
      (range.max_cents.blank? || budget_cents <= range.max_cents)
  end
end
