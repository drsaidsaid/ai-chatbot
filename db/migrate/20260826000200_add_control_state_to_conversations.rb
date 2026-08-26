# frozen_string_literal: true

class AddControlStateToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :control_state, :integer, null: false, default: 0
    add_column :conversations, :control_version, :integer, null: false, default: 0
  end
end
