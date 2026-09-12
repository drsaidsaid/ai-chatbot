# frozen_string_literal: true

class AiLeadEmployee::KnowledgeAuthorityLock
  def self.acquire!(account_id)
    Account.where(id: account_id).lock.pick(:id)
  end
end
