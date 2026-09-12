# frozen_string_literal: true

class AddOfferSelectionVersion < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :offer_selection_version, :bigint, null: false, default: 0
    add_check_constraint :conversations, 'offer_selection_version >= 0', name: 'conversations_offer_selection_version_nonnegative'
  end
end
