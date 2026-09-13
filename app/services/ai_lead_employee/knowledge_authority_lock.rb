# frozen_string_literal: true

class AiLeadEmployee::KnowledgeAuthorityLock
  # Knowledge writers take this advisory lock before a write can acquire an
  # Account foreign-key lock. Final answering follows the same order, then takes
  # Conversation. Booking takes Account then Conversation, so either path can
  # wait before taking Conversation and cannot form an Account/Conversation cycle.
  LOCK_NAMESPACE = 1_263_421_783

  def self.acquire!(account_id)
    ApplicationRecord.connection.execute(
      "SELECT pg_advisory_xact_lock(#{LOCK_NAMESPACE}, #{Integer(account_id)})"
    )
  end

  def self.acquire_for_answer!(account_id)
    acquire!(account_id)
    Account.where(id: account_id).lock('FOR KEY SHARE').load
  end
end
