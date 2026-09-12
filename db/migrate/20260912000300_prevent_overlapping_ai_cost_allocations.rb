# frozen_string_literal: true

class PreventOverlappingAiCostAllocations < ActiveRecord::Migration[7.1]
  def change
    add_exclusion_constraint :ai_account_cost_allocations,
                             'account_id WITH =, category WITH =, currency WITH =, ' \
                             "daterange(period_started_on, period_ended_on, '[]') WITH &&",
                             using: :gist,
                             name: 'ai_cost_allocations_no_overlap'
  end
end
