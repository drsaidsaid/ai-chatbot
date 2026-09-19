class AddAiResumeMessageBoundaryToConversations < ActiveRecord::Migration[7.2]
  def change
    add_column :conversations, :ai_resume_after_message_id, :bigint, null: false, default: 0
  end
end
