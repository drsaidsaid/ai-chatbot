class MacrosExecutionJob < ApplicationJob
  queue_as :medium

  def perform(macro, conversation_ids:, user:)
    access = AiLeadEmployee::AccessScope.new(account: macro.account, user: user)
    return unless macro.global? || macro.created_by_id == user.id

    access.conversations.where(display_id: conversation_ids.to_a).find_each do |conversation|
      # Old queued macros can assign work and disclose it through webhooks.
      next unless access.administrator?

      ::Macros::ExecutionService.new(macro, conversation, user).perform
    end
  end
end
