class RoomChannel < ApplicationCable::Channel
  def subscribed
    current_user
    current_account
    return reject unless live_subscription?

    ensure_stream
    update_subscription
    broadcast_presence
  rescue ActiveRecord::RecordNotFound
    reject
  end

  def update_presence
    return reject unless live_subscription?

    update_subscription
    broadcast_presence
  end

  private

  def broadcast_presence
    return if @current_account.blank?

    data = { account_id: @current_account.id, users: ::OnlineStatusTracker.get_available_users(@current_account.id) }
    if @current_user.is_a?(User)
      ids = access.contacts.pluck(:id).map(&:to_s)
      data[:contacts] = ::OnlineStatusTracker.get_available_contacts(@current_account.id).slice(*ids)
    end
    ActionCable.server.broadcast(pubsub_token, { event: 'presence.update', data: data })
  end

  def ensure_stream
    stream_from pubsub_token, coder: ActiveSupport::JSON do |payload|
      if payload['event'] == 'access.changed'
        transmit(payload)
        stop_all_streams unless live_subscription?
      elsif live_subscription? && visible_payload?(payload)
        transmit(payload)
      else
        stop_all_streams unless live_subscription?
      end
    end
  end

  def visible_payload?(payload)
    return true if @current_user.is_a?(Contact)

    AiLeadEmployee::RealtimeDelivery.new(members: [], event: payload['event'], data: payload.fetch('data', {}))
                                    .authorized_user?(@current_user)
  end

  def access
    AiLeadEmployee::AccessScope.new(account: @current_account, user: @current_user)
  end

  def live_subscription?
    return true if @current_user.is_a?(Contact)

    connection.authenticated_user&.id == @current_user&.id && access.membership.present?
  end

  def update_subscription
    return if @current_account.blank?

    ::OnlineStatusTracker.update_presence(@current_account.id, @current_user.class.name, @current_user.id)
  end

  def pubsub_token
    @pubsub_token ||= params[:pubsub_token]
  end

  def current_user
    @current_user ||= if params[:user_id].blank?
                        ContactInbox.find_by!(pubsub_token: pubsub_token).contact
                      else
                        User.find_by!(pubsub_token: pubsub_token, id: params[:user_id])
                      end
  end

  def current_account
    return if current_user.blank?

    @current_account ||= if @current_user.is_a? Contact
                           @current_user.account
                         else
                           @current_user.accounts.find(params[:account_id])
                         end
  end
end
