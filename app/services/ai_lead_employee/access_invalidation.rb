# frozen_string_literal: true

class AiLeadEmployee::AccessInvalidation
  def self.notify(account_id:, user_ids:)
    User.where(id: user_ids.compact.uniq).pluck(:pubsub_token).each do |token|
      ActionCable.server.broadcast(token, { event: 'access.changed', data: { account_id: account_id } })
    end
  end
end
