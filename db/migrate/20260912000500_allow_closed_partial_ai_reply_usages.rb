# frozen_string_literal: true

class AllowClosedPartialAiReplyUsages < ActiveRecord::Migration[7.1]
  def change
    remove_check_constraint :ai_reply_usages,
                            "status IN ('reserved', 'settled', 'released')",
                            name: 'ai_reply_usages_status'
    add_check_constraint :ai_reply_usages,
                         "status IN ('reserved', 'settled', 'released', 'partially_delivered', 'partial_failure_closed')",
                         name: 'ai_reply_usages_status'
  end
end
